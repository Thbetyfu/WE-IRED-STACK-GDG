package database

import (
	"errors"
	"fmt"
	"io/fs"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	"github.com/golang-migrate/migrate/v4/source/iofs"
)

// RunMigrations runs pending database migrations up from an embedded or filesystem fs.FS.
func RunMigrations(databaseURL string, migrationFS fs.FS, dir string) error {
	driver, err := iofs.New(migrationFS, dir)
	if err != nil {
		return fmt.Errorf("failed to create migration source driver: %w", err)
	}

	m, err := migrate.NewWithSourceInstance("iofs", driver, databaseURL)
	if err != nil {
		return fmt.Errorf("failed to create migrate instance: %w", err)
	}
	defer m.Close()

	if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("migration up failed: %w", err)
	}

	return nil
}

// RollbackMigration rolls back the last migration step.
func RollbackMigration(databaseURL string, migrationFS fs.FS, dir string) error {
	driver, err := iofs.New(migrationFS, dir)
	if err != nil {
		return fmt.Errorf("failed to create migration source driver: %w", err)
	}

	m, err := migrate.NewWithSourceInstance("iofs", driver, databaseURL)
	if err != nil {
		return fmt.Errorf("failed to create migrate instance: %w", err)
	}
	defer m.Close()

	if err := m.Steps(-1); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("migration rollback failed: %w", err)
	}

	return nil
}
