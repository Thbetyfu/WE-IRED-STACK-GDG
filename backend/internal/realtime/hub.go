package realtime

import (
	"context"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait      = 5 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 4096
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for dev/embedded apps
	},
}

type Client struct {
	hub        *Hub
	conn       *websocket.Conn
	incidentID string
	rtID       string
	userID     string
	role       string
	send       chan *Event
}

type Hub struct {
	mu    sync.RWMutex
	rooms map[string]map[*Client]bool // incidentID -> clients
	store EventStore
}

func NewHub(store EventStore) *Hub {
	return &Hub{
		rooms: make(map[string]map[*Client]bool),
		store: store,
	}
}

func (h *Hub) Register(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	room, exists := h.rooms[c.incidentID]
	if !exists {
		room = make(map[*Client]bool)
		h.rooms[c.incidentID] = room
	}
	room[c] = true
}

func (h *Hub) Unregister(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if room, exists := h.rooms[c.incidentID]; exists {
		if _, ok := room[c]; ok {
			delete(room, c)
			close(c.send)
			if len(room) == 0 {
				delete(h.rooms, c.incidentID)
			}
		}
	}
}

func (h *Hub) BroadcastEvent(ctx context.Context, incidentID string, e *Event) error {
	e.IncidentID = &incidentID

	// Persist to events table first (SDD Section 5)
	if err := h.store.SaveEvent(ctx, e); err != nil {
		return err
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	if room, exists := h.rooms[incidentID]; exists {
		for client := range room {
			select {
			case client.send <- e:
			default:
				// If send channel buffer is full, do not block other clients
				log.Printf("warning: client %s send buffer full, dropping event %d", client.userID, e.ID)
			}
		}
	}

	return nil
}

func (h *Hub) SendMissedEvents(ctx context.Context, c *Client, lastEventID int64) error {
	if lastEventID <= 0 {
		return nil
	}

	events, err := h.store.GetEventsAfter(ctx, lastEventID, &c.incidentID, &c.rtID, 200)
	if err != nil {
		return err
	}

	for _, e := range events {
		select {
		case c.send <- e:
		default:
			return nil
		}
	}
	return nil
}

func (c *Client) ReadPump() {
	defer func() {
		c.hub.Unregister(c)
		_ = c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, _, err := c.conn.ReadMessage()
		if err != nil {
			break
		}
	}
}

func (c *Client) WritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		_ = c.conn.Close()
	}()

	for {
		select {
		case event, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.conn.WriteJSON(event); err != nil {
				return
			}

		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
