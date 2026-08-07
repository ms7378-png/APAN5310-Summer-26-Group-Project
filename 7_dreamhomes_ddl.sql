-- ============================================================
-- Dream Homes NYC Enterprise Real Estate Relational Database System
-- Schema DDL Definition (PostgreSQL 18 Standard) - Final Parity Version
-- Includes Login User Creation for RBAC Roles
-- ============================================================

-- 1. Staging raw CSV table
CREATE TABLE staging_raw_data (
    raw_id INT PRIMARY KEY,
    property_address VARCHAR(255),
    city_name VARCHAR(100),
    state_code VARCHAR(10),
    zip_code VARCHAR(20),
    neighborhood_name VARCHAR(100),
    property_type VARCHAR(50),
    bedrooms INT,
    bathrooms NUMERIC(3,1),
    sqft INT,
    asking_price NUMERIC(12,2),
    agreed_price NUMERIC(12,2),
    transaction_date DATE,
    status VARCHAR(50),
    agent_full_name VARCHAR(150),
    agent_email VARCHAR(150),
    agent_phone VARCHAR(50),
    office_name VARCHAR(150),
    client_full_name VARCHAR(150),
    client_email VARCHAR(150),
    client_phone VARCHAR(50),
    client_type VARCHAR(50),
    service_type VARCHAR(50)
);

-- 2. Regional Geography Tables
CREATE TABLE states (
    state_id SERIAL PRIMARY KEY,
    state_name VARCHAR(100) NOT NULL UNIQUE,
    state_abbr VARCHAR(10) NOT NULL UNIQUE
);

CREATE TABLE cities (
    city_id SERIAL PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL,
    state_id INT NOT NULL REFERENCES states(state_id) ON DELETE RESTRICT
);

CREATE TABLE zip_codes (
    zip_code_id SERIAL PRIMARY KEY,
    zip_code VARCHAR(20) NOT NULL UNIQUE,
    city_id INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT
);

CREATE TABLE neighborhoods (
    neighborhood_id SERIAL PRIMARY KEY,
    neighborhood_name VARCHAR(100) NOT NULL,
    city_id INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    CONSTRAINT uq_neighborhood_city UNIQUE (neighborhood_name, city_id)
);

-- 3. Office & Brokerage Structure
CREATE TABLE offices (
    office_id SERIAL PRIMARY KEY,
    office_name VARCHAR(150) NOT NULL UNIQUE,
    address VARCHAR(255) NOT NULL,
    city_id INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    zip_code_id INT NOT NULL REFERENCES zip_codes(zip_code_id) ON DELETE RESTRICT,
    phone VARCHAR(50),
    email VARCHAR(150)
);

CREATE TABLE agents (
    agent_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(50),
    office_id INT NOT NULL REFERENCES offices(office_id) ON DELETE RESTRICT
);

-- 4. Clients & Assignments
CREATE TABLE clients (
    client_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(50),
    client_type VARCHAR(50),
    assigned_agent_id INT REFERENCES agents(agent_id) ON DELETE SET NULL
);

CREATE TABLE service_types (
    service_type_id SERIAL PRIMARY KEY,
    service_name VARCHAR(50) NOT NULL UNIQUE,
    default_commission_pct NUMERIC(5,2) DEFAULT 5.00
);

CREATE TABLE client_agent_assignments (
    assignment_id SERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    agent_id INT NOT NULL REFERENCES agents(agent_id) ON DELETE CASCADE,
    service_type_id INT REFERENCES service_types(service_type_id) ON DELETE SET NULL,
    status VARCHAR(50) DEFAULT 'Active',
    CONSTRAINT uq_client_agent_service UNIQUE (client_id, agent_id, service_type_id)
);

-- 5. Properties & Features
CREATE TABLE property_types (
    property_type_id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE properties (
    property_id SERIAL PRIMARY KEY,
    address VARCHAR(255) NOT NULL,
    neighborhood_id INT NOT NULL REFERENCES neighborhoods(neighborhood_id) ON DELETE RESTRICT,
    zip_code_id INT NOT NULL REFERENCES zip_codes(zip_code_id) ON DELETE RESTRICT,
    property_type_id INT NOT NULL REFERENCES property_types(property_type_id) ON DELETE RESTRICT,
    bedrooms INT NOT NULL,
    bathrooms NUMERIC(3,1) NOT NULL,
    sqft INT NOT NULL,
    CONSTRAINT uq_property_address UNIQUE (address, zip_code_id)
);

CREATE TABLE property_features (
    feature_id SERIAL PRIMARY KEY,
    property_id INT NOT NULL REFERENCES properties(property_id) ON DELETE CASCADE,
    feature_name VARCHAR(100) NOT NULL,
    feature_value VARCHAR(255),
    CONSTRAINT uq_property_feature UNIQUE (property_id, feature_name)
);

-- 6. Listings & Transactions
CREATE TABLE listings (
    listing_id SERIAL PRIMARY KEY,
    property_id INT NOT NULL REFERENCES properties(property_id) ON DELETE RESTRICT,
    seller_client_id INT NOT NULL REFERENCES clients(client_id) ON DELETE RESTRICT,
    agent_id INT NOT NULL REFERENCES agents(agent_id) ON DELETE RESTRICT,
    service_type_id INT NOT NULL REFERENCES service_types(service_type_id) ON DELETE RESTRICT,
    asking_price NUMERIC(12,2) NOT NULL,
    list_date DATE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Active',
    CONSTRAINT uq_property_listdate UNIQUE (property_id, list_date)
);

CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    listing_id INT NOT NULL UNIQUE REFERENCES listings(listing_id) ON DELETE RESTRICT,
    buyer_client_id INT NOT NULL REFERENCES clients(client_id) ON DELETE RESTRICT,
    closing_agent_id INT NOT NULL REFERENCES agents(agent_id) ON DELETE RESTRICT,
    agreed_price NUMERIC(12,2) NOT NULL,
    closing_date DATE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Closed'
);

CREATE TABLE transaction_participants (
    participant_id SERIAL PRIMARY KEY,
    transaction_id INT NOT NULL REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    client_id INT NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL,
    notes TEXT,
    CONSTRAINT uq_tx_client_role UNIQUE (transaction_id, client_id, role)
);

-- 7. Revenues & Expenses
CREATE TABLE revenues (
    revenue_id SERIAL PRIMARY KEY,
    transaction_id INT NOT NULL UNIQUE REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    amount NUMERIC(12,2) NOT NULL,
    revenue_date DATE NOT NULL,
    notes TEXT
);

CREATE TABLE expense_categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE expenses (
    expense_id SERIAL PRIMARY KEY,
    transaction_id INT NOT NULL REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    category_id INT NOT NULL REFERENCES expense_categories(category_id) ON DELETE RESTRICT,
    amount NUMERIC(12,2) NOT NULL,
    expense_date DATE NOT NULL,
    CONSTRAINT uq_tx_category UNIQUE (transaction_id, category_id)
);

-- 8. Operations & School Proximity
CREATE TABLE appointments (
    appointment_id SERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    agent_id INT NOT NULL REFERENCES agents(agent_id) ON DELETE CASCADE,
    listing_id INT NOT NULL REFERENCES listings(listing_id) ON DELETE CASCADE,
    appointment_datetime TIMESTAMP NOT NULL,
    appointment_type VARCHAR(50),
    status VARCHAR(50),
    notes TEXT,
    CONSTRAINT uq_appointment_client_listing UNIQUE (client_id, listing_id, appointment_datetime)
);

CREATE TABLE open_houses (
    open_house_id SERIAL PRIMARY KEY,
    listing_id INT NOT NULL REFERENCES listings(listing_id) ON DELETE CASCADE,
    agent_id INT NOT NULL REFERENCES agents(agent_id) ON DELETE CASCADE,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    attendees_count INT DEFAULT 0,
    CONSTRAINT uq_openhouse_listing_time UNIQUE (listing_id, start_time)
);

CREATE TABLE open_house_attendees (
    attendee_id SERIAL PRIMARY KEY,
    open_house_id INT NOT NULL REFERENCES open_houses(open_house_id) ON DELETE CASCADE,
    client_id INT NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    signed_in_at TIMESTAMP NOT NULL,
    interest_level VARCHAR(50),
    CONSTRAINT uq_oh_attendee UNIQUE (open_house_id, client_id)
);

CREATE TABLE school_districts (
    district_id SERIAL PRIMARY KEY,
    district_name VARCHAR(150) NOT NULL UNIQUE,
    city_id INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    state_id INT NOT NULL REFERENCES states(state_id) ON DELETE RESTRICT
);

CREATE TABLE schools (
    school_id SERIAL PRIMARY KEY,
    school_name VARCHAR(150) NOT NULL UNIQUE,
    district_id INT NOT NULL REFERENCES school_districts(district_id) ON DELETE RESTRICT,
    school_level VARCHAR(50),
    rating NUMERIC(3,1),
    address VARCHAR(255),
    city_id INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    zip_code_id INT NOT NULL REFERENCES zip_codes(zip_code_id) ON DELETE RESTRICT
);

CREATE TABLE property_school_proximity (
    proximity_id SERIAL PRIMARY KEY,
    property_id INT NOT NULL REFERENCES properties(property_id) ON DELETE CASCADE,
    school_id INT NOT NULL REFERENCES schools(school_id) ON DELETE CASCADE,
    distance_miles NUMERIC(4,2),
    CONSTRAINT uq_property_school UNIQUE (property_id, school_id)
);

-- Performance Indices
CREATE INDEX idx_listings_property ON listings(property_id);
CREATE INDEX idx_listings_agent ON listings(agent_id);
CREATE INDEX idx_transactions_listing ON transactions(listing_id);
CREATE INDEX idx_transactions_closing_agent ON transactions(closing_agent_id);
CREATE INDEX idx_properties_neighborhood ON properties(neighborhood_id);
CREATE INDEX idx_expenses_transaction ON expenses(transaction_id);
CREATE INDEX idx_revenues_transaction ON revenues(transaction_id);

-- ROLE-BASED ACCESS CONTROL (RBAC) SECURITY CONFIGURATION WITH LOGIN USERS
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'analyst_role') THEN
        CREATE ROLE analyst_role;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'executive_role') THEN
        CREATE ROLE executive_role;
    END IF;

    -- Create Login Users inheriting Roles for Metabase BI & Analyst Login
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'metabase_user') THEN
        CREATE USER metabase_user WITH LOGIN PASSWORD 'MetabaseExecutive2026!';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'analyst_user') THEN
        CREATE USER analyst_user WITH LOGIN PASSWORD 'AnalystSecure2026!';
    END IF;
END $$;

GRANT executive_role TO metabase_user;
GRANT analyst_role TO analyst_user;

GRANT CONNECT ON DATABASE dreamhomes_nyc TO analyst_role, executive_role;
GRANT USAGE ON SCHEMA public TO analyst_role, executive_role;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO analyst_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO executive_role;

-- Grant Full Sequence Usage to prevent serial key permission errors
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO analyst_role, executive_role;
