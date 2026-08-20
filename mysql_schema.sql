-- MiarhPen MySQL mirror schema — matches the local SQLite schema in
-- lib/core/db/app_database.dart. This database is a one-way, on-demand
-- export target for desktop viewing (MySQL Workbench, phpMyAdmin, etc.)
-- — the Flutter app's real, primary, offline database remains local
-- SQLite on the device. Nothing here is read by the app at runtime.

CREATE DATABASE IF NOT EXISTS miarhpen
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE miarhpen;

CREATE TABLE IF NOT EXISTS users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  -- VARCHAR(191), not 255: on MySQL 5.6 an InnoDB index over utf8mb4
  -- (4 bytes/char) is capped at 767 bytes, and 255*4 exceeds that —
  -- 191*4=764 is the standard safe max for a UNIQUE/indexed column here.
  username VARCHAR(191) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  password_salt VARCHAR(255),
  pin_hash VARCHAR(255),
  biometric_enabled TINYINT(1) NOT NULL DEFAULT 0,
  remember_me TINYINT(1) NOT NULL DEFAULT 0,
  session_timeout_min INT NOT NULL DEFAULT 5,
  currency_code VARCHAR(10) NOT NULL DEFAULT 'PHP',
  currency_symbol VARCHAR(10) NOT NULL DEFAULT '₱',
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS accounting_periods (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE,
  beginning_balance DECIMAL(14,2) NOT NULL DEFAULT 0,
  total_income DECIMAL(14,2) NOT NULL DEFAULT 0,
  total_expense DECIMAL(14,2) NOT NULL DEFAULT 0,
  ending_balance DECIMAL(14,2),
  status VARCHAR(10) NOT NULL DEFAULT 'OPEN',
  created_at DATETIME NOT NULL,
  closed_at DATETIME,
  INDEX idx_periods_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS accounts (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  type VARCHAR(30) NOT NULL,
  description TEXT,
  beginning_balance DECIMAL(14,2) NOT NULL DEFAULT 0,
  current_balance DECIMAL(14,2) NOT NULL DEFAULT 0,
  credit_limit DECIMAL(14,2),
  outstanding_balance DECIMAL(14,2),
  statement_date INT,
  due_date INT,
  linked_account_id INT,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX idx_accounts_type (type),
  INDEX idx_accounts_active (is_active),
  CONSTRAINT fk_accounts_linked FOREIGN KEY (linked_account_id)
    REFERENCES accounts(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS income_categories (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(191) NOT NULL UNIQUE,
  description TEXT,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS expense_categories (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(191) NOT NULL UNIQUE,
  description TEXT,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS transactions (
  id INT PRIMARY KEY AUTO_INCREMENT,
  type VARCHAR(10) NOT NULL,
  date DATE NOT NULL,
  account_id INT NOT NULL,
  income_category_id INT,
  expense_category_id INT,
  amount DECIMAL(14,2) NOT NULL,
  description TEXT,
  reference_number VARCHAR(255),
  notes TEXT,
  attachment_path VARCHAR(500),
  accounting_period_id INT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX idx_txn_account (account_id),
  INDEX idx_txn_date (date),
  INDEX idx_txn_type (type),
  INDEX idx_txn_income_cat (income_category_id),
  INDEX idx_txn_expense_cat (expense_category_id),
  INDEX idx_txn_period (accounting_period_id),
  CONSTRAINT fk_txn_account FOREIGN KEY (account_id) REFERENCES accounts(id),
  CONSTRAINT fk_txn_income_cat FOREIGN KEY (income_category_id) REFERENCES income_categories(id),
  CONSTRAINT fk_txn_expense_cat FOREIGN KEY (expense_category_id) REFERENCES expense_categories(id),
  CONSTRAINT fk_txn_period FOREIGN KEY (accounting_period_id) REFERENCES accounting_periods(id),
  CONSTRAINT chk_txn_amount CHECK (amount > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS transfers (
  id INT PRIMARY KEY AUTO_INCREMENT,
  date DATE NOT NULL,
  from_account_id INT NOT NULL,
  to_account_id INT NOT NULL,
  amount DECIMAL(14,2) NOT NULL,
  reference_number VARCHAR(255),
  notes TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX idx_transfer_from (from_account_id),
  INDEX idx_transfer_to (to_account_id),
  INDEX idx_transfer_date (date),
  CONSTRAINT fk_transfer_from FOREIGN KEY (from_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_transfer_to FOREIGN KEY (to_account_id) REFERENCES accounts(id),
  CONSTRAINT chk_transfer_amount CHECK (amount > 0),
  CONSTRAINT chk_transfer_accounts CHECK (from_account_id != to_account_id)
) ENGINE=InnoDB;
