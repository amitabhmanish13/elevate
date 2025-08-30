-- Database initialization for Cilium Network Demo
-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    user_id INTEGER REFERENCES users(id),
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (name, email) VALUES 
    ('Alice Johnson', 'alice@demo.com'),
    ('Bob Smith', 'bob@demo.com'),
    ('Carol Davis', 'carol@demo.com')
ON CONFLICT (email) DO NOTHING;

INSERT INTO tasks (title, description, user_id, completed) VALUES 
    ('Setup Cilium Demo', 'Configure Cilium with Hubble for network visibility', 1, true),
    ('Deploy Monitoring Stack', 'Install Prometheus and Grafana', 1, true),
    ('Create Network Policies', 'Implement security policies using Cilium', 2, false),
    ('Test Application Flow', 'Verify end-to-end connectivity', 2, false),
    ('Generate Demo Traffic', 'Create sample network traffic for visibility', 3, false)
ON CONFLICT DO NOTHING;