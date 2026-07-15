--[[
    database.lua (shared)
    Comprehensive database schema for the AI Insurance Adjuster system.
    Maintains backward compatibility while adding support for:
    - Vehicle information tracking
    - Driver risk profiles
    - Insurance policy tiers
    - Witness statements
    - Police/EMS reports
    - Enhanced claims with investigation stages
]]

-- Initialize all database tables on resource start
CreateThread(function()
    -- Original claims table (maintained for backward compatibility)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_claims (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            vehicle_model VARCHAR(50),
            damage_percent FLOAT,
            impact_speed FLOAT,
            decision VARCHAR(20),
            payout INT,
            suspicion_score INT,
            reasoning TEXT,
            flags TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    -- Original fraud scores table (maintained for backward compatibility)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_fraud_scores (
            citizenid VARCHAR(50) PRIMARY KEY,
            score INT DEFAULT 0,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    -- Vehicle information table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_vehicles (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            plate VARCHAR(20) NOT NULL,
            vehicle_model VARCHAR(50),
            vehicle_class VARCHAR(50),
            vin VARCHAR(50),
            mileage INT DEFAULT 0,
            vehicle_value DECIMAL(10,2),
            policy_tier VARCHAR(20) DEFAULT 'standard',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY (plate),
            INDEX (citizenid),
            INDEX (policy_tier)
        )
    ]])

    -- Vehicle repair history
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_vehicle_repairs (
            id INT AUTO_INCREMENT PRIMARY KEY,
            vehicle_id INT NOT NULL,
            repair_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            description TEXT,
            cost DECIMAL(10,2),
            mechanic VARCHAR(100),
            INDEX (vehicle_id),
            FOREIGN KEY (vehicle_id) REFERENCES insurance_vehicles(id) ON DELETE CASCADE
        )
    ]])

    -- Driver risk profile
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_driver_profiles (
            citizenid VARCHAR(50) PRIMARY KEY,
            character_name VARCHAR(100),
            total_claims INT DEFAULT 0,
            approved_claims INT DEFAULT 0,
            denied_claims INT DEFAULT 0,
            average_speed DECIMAL(6,2),
            night_driving_freq DECIMAL(5,2),
            rain_driving_freq DECIMAL(5,2),
            police_encounters INT DEFAULT 0,
            dui_count INT DEFAULT 0,
            fraud_suspicion INT DEFAULT 0,
            aggressive_driving_score INT DEFAULT 0,
            safe_driving_streak INT DEFAULT 0,
            risk_score INT DEFAULT 50,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX (risk_score)
        )
    ]])

    -- Insurance policy tiers
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_policy_tiers (
            tier_name VARCHAR(20) PRIMARY KEY,
            display_name VARCHAR(50),
            max_payout DECIMAL(10,2),
            deductible DECIMAL(10,2),
            luxury_coverage BOOLEAN DEFAULT FALSE,
            roadside_assistance BOOLEAN DEFAULT FALSE,
            rental_reimbursement BOOLEAN DEFAULT FALSE,
            medical_coverage BOOLEAN DEFAULT FALSE,
            approval_priority INT DEFAULT 5,
            description TEXT
        )
    ]])

    -- Enhanced claims table with investigation stages
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_claims_enhanced (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_number VARCHAR(30) UNIQUE,
            citizenid VARCHAR(50) NOT NULL,
            vehicle_id INT,
            policy_tier VARCHAR(20) DEFAULT 'standard',
            investigation_stage VARCHAR(20) DEFAULT 'evidence_collection',
            
            -- Accident details
            accident_date TIMESTAMP,
            gps_x DECIMAL(10,6),
            gps_y DECIMAL(10,6),
            gps_z DECIMAL(10,6),
            street_name VARCHAR(100),
            weather VARCHAR(50),
            road_type VARCHAR(50),
            
            -- Speed data
            speed_before_impact DECIMAL(6,2),
            speed_at_impact DECIMAL(6,2),
            
            -- Collision details
            number_of_impacts INT DEFAULT 1,
            impact_direction VARCHAR(50),
            rollovers BOOLEAN DEFAULT FALSE,
            airbag_deployed BOOLEAN DEFAULT FALSE,
            vehicle_flipped BOOLEAN DEFAULT FALSE,
            engine_stalled BOOLEAN DEFAULT FALSE,
            fire BOOLEAN DEFAULT FALSE,
            explosion BOOLEAN DEFAULT FALSE,
            
            -- Occupant details
            occupants INT DEFAULT 1,
            seatbelt_status BOOLEAN,
            driver_ejected BOOLEAN DEFAULT FALSE,
            vehicle_drivable BOOLEAN DEFAULT FALSE,
            
            -- Vehicle health at time of accident
            engine_health INT,
            body_health INT,
            fuel_tank_health INT,
            tire_condition JSON,
            door_damage JSON,
            window_damage JSON,
            
            -- Decision and payout
            decision VARCHAR(20),
            confidence INT,
            fraud_risk VARCHAR(20),
            risk_score INT,
            approved_amount DECIMAL(10,2),
            deductible DECIMAL(10,2),
            
            -- Reports
            mechanic_report JSON,
            witness_reports JSON,
            police_reports JSON,
            ems_reports JSON,
            
            -- AI analysis
            reasoning TEXT,
            flags JSON,
            next_action VARCHAR(100),
            prompt_version VARCHAR(20) DEFAULT 'v1',
            ai_provider VARCHAR(30) DEFAULT 'gemini',
            prompt_hash VARCHAR(64),
            adjuster_notes TEXT,
            investigation_summary TEXT,
            mechanic_summary TEXT,
            
            -- Follow-up
            follow_up_questions JSON,
            player_answers JSON,
            
            -- Timestamps
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            completed_at TIMESTAMP NULL,
            
            INDEX (citizenid),
            INDEX (vehicle_id),
            INDEX (policy_tier),
            INDEX (investigation_stage),
            INDEX (accident_date),
            INDEX (decision),
            FOREIGN KEY (vehicle_id) REFERENCES insurance_vehicles(id) ON DELETE SET NULL
        )
    ]])

    -- Witness statements
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_witnesses (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_id INT NOT NULL,
            witness_citizenid VARCHAR(50),
            witness_name VARCHAR(100),
            distance DECIMAL(6,2),
            position_x DECIMAL(10,6),
            position_y DECIMAL(10,6),
            position_z DECIMAL(10,6),
            line_of_sight BOOLEAN DEFAULT FALSE,
            likely_witness BOOLEAN DEFAULT FALSE,
            statement TEXT,
            summary TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX (claim_id),
            FOREIGN KEY (claim_id) REFERENCES insurance_claims_enhanced(id) ON DELETE CASCADE
        )
    ]])

    -- Police reports
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_police_reports (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_id INT NOT NULL,
            report_number VARCHAR(50),
            officer_name VARCHAR(100),
            citation_type VARCHAR(50),
            description TEXT,
            fine_amount DECIMAL(10,2),
            report_date TIMESTAMP,
            attached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX (claim_id),
            INDEX (citation_type),
            FOREIGN KEY (claim_id) REFERENCES insurance_claims_enhanced(id) ON DELETE CASCADE
        )
    ]])

    -- EMS reports
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_ems_reports (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_id INT NOT NULL,
            paramedic_name VARCHAR(100),
            injury_severity VARCHAR(50),
            injuries JSON,
            treatment TEXT,
            unconscious BOOLEAN DEFAULT FALSE,
            passengers INT DEFAULT 0,
            transported BOOLEAN DEFAULT FALSE,
            hospital_name VARCHAR(100),
            report_date TIMESTAMP,
            attached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX (claim_id),
            INDEX (injury_severity),
            FOREIGN KEY (claim_id) REFERENCES insurance_claims_enhanced(id) ON DELETE CASCADE
        )
    ]])

    -- Mechanic inspection reports
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_mechanic_reports (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_id INT NOT NULL,
            mechanic_name VARCHAR(100),
            inspection_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            damaged_parts JSON,
            parts_cost DECIMAL(10,2),
            labor_cost DECIMAL(10,2),
            repair_time_hours DECIMAL(6,2),
            total_cost DECIMAL(10,2),
            notes TEXT,
            INDEX (claim_id),
            FOREIGN KEY (claim_id) REFERENCES insurance_claims_enhanced(id) ON DELETE CASCADE
        )
    ]])

    -- Claim history for persistent investigations
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_claim_history (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_id INT NOT NULL,
            claim_number VARCHAR(50),
            citizenid VARCHAR(50) NOT NULL,
            company_name VARCHAR(100),
            decision VARCHAR(20),
            approved_amount DECIMAL(10,2),
            summary TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX (citizenid),
            INDEX (claim_id)
        )
    ]])

    -- Adjuster memory per player
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_adjuster_memory (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) UNIQUE NOT NULL,
            claim_count INT DEFAULT 0,
            summary TEXT,
            last_claim_at TIMESTAMP NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])

    -- Repair orders generated after approval
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_repair_orders (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_id INT NOT NULL,
            citizenid VARCHAR(50) NOT NULL,
            company_name VARCHAR(100),
            status VARCHAR(30) DEFAULT 'pending',
            approved_amount DECIMAL(10,2),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX (citizenid),
            INDEX (claim_id)
        )
    ]])

    -- AI response cache
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ai_response_cache (
            id INT AUTO_INCREMENT PRIMARY KEY,
            prompt_hash VARCHAR(64) NOT NULL,
            prompt_version VARCHAR(20) DEFAULT 'v1',
            provider VARCHAR(30),
            model VARCHAR(100),
            response_text TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY (prompt_hash, prompt_version)
        )
    ]])

    -- AI request logs
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ai_logs (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_id INT NULL,
            provider VARCHAR(30),
            model VARCHAR(100),
            prompt_version VARCHAR(20) DEFAULT 'v1',
            prompt_hash VARCHAR(64),
            tokens INT NULL,
            response_time_ms INT DEFAULT 0,
            success BOOLEAN DEFAULT TRUE,
            error_reason VARCHAR(255),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX (claim_id),
            INDEX (provider),
            INDEX (success)
        )
    ]])

    -- Uploaded evidence photos (enhanced with metadata)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_evidence_photos (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_id INT NOT NULL,
            citizenid VARCHAR(50) NOT NULL,
            photo_url VARCHAR(512),
            caption VARCHAR(255),
            photo_type VARCHAR(50) DEFAULT 'general',
            damage_area VARCHAR(100) DEFAULT 'unspecified',
            metadata JSON,
            uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX (claim_id),
            INDEX (citizenid),
            INDEX (photo_type)
        )
    ]])

    -- Dashcam footage
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_dashcam_footage (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_id INT NOT NULL,
            citizenid VARCHAR(50) NOT NULL,
            footage_url VARCHAR(512),
            duration_seconds INT,
            start_time TIMESTAMP,
            end_time TIMESTAMP,
            file_size BIGINT,
            resolution VARCHAR(50),
            metadata JSON,
            uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX (claim_id),
            INDEX (citizenid)
        )
    ]])

    -- GPS tracking data
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_gps_tracking (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_id INT NOT NULL,
            citizenid VARCHAR(50) NOT NULL,
            vehicle_plate VARCHAR(20),
            latitude DECIMAL(10,6),
            longitude DECIMAL(10,6),
            altitude DECIMAL(10,2),
            speed DECIMAL(6,2),
            heading DECIMAL(6,2),
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            tracking_type VARCHAR(50) DEFAULT 'accident',
            INDEX (claim_id),
            INDEX (citizenid),
            INDEX (timestamp)
        )
    ]])

    -- Towing service requests
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_towing_requests (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_id INT NOT NULL,
            citizenid VARCHAR(50) NOT NULL,
            vehicle_plate VARCHAR(20),
            pickup_location_x DECIMAL(10,6),
            pickup_location_y DECIMAL(10,6),
            pickup_location_z DECIMAL(10,2),
            dropoff_location_x DECIMAL(10,6),
            dropoff_location_y DECIMAL(10,6),
            dropoff_location_z DECIMAL(10,2),
            tow_company VARCHAR(100),
            driver_name VARCHAR(100),
            status VARCHAR(30) DEFAULT 'pending',
            estimated_cost DECIMAL(10,2),
            actual_cost DECIMAL(10,2),
            requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            completed_at TIMESTAMP NULL,
            INDEX (claim_id),
            INDEX (citizenid),
            INDEX (status)
        )
    ]])

    -- Rental car coordination
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_rental_cars (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_id INT NOT NULL,
            citizenid VARCHAR(50) NOT NULL,
            rental_company VARCHAR(100),
            vehicle_model VARCHAR(50),
            pickup_date DATE,
            return_date DATE,
            daily_rate DECIMAL(10,2),
            total_cost DECIMAL(10,2),
            coverage_type VARCHAR(50) DEFAULT 'standard',
            status VARCHAR(30) DEFAULT 'pending',
            confirmation_number VARCHAR(50),
            requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            confirmed_at TIMESTAMP NULL,
            INDEX (claim_id),
            INDEX (citizenid),
            INDEX (status)
        )
    ]])

    -- Medical billing integration
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_medical_billing (
            id INT AUTO_INCREMENT PRIMARY KEY,
            claim_id INT NOT NULL,
            citizenid VARCHAR(50) NOT NULL,
            provider_name VARCHAR(100),
            provider_type VARCHAR(50),
            treatment_date DATE,
            service_type VARCHAR(100),
            diagnosis VARCHAR(255),
            procedure_codes JSON,
            billed_amount DECIMAL(10,2),
            covered_amount DECIMAL(10,2),
            patient_responsibility DECIMAL(10,2),
            status VARCHAR(30) DEFAULT 'pending',
            invoice_number VARCHAR(100),
            submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            processed_at TIMESTAMP NULL,
            INDEX (claim_id),
            INDEX (citizenid),
            INDEX (status)
        )
    ]])

    -- Mobile app API tokens
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS insurance_mobile_tokens (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            device_id VARCHAR(100),
            device_type VARCHAR(50),
            token VARCHAR(255) NOT NULL,
            expires_at TIMESTAMP,
            last_used TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY (token),
            INDEX (citizenid),
            INDEX (device_id)
        )
    ]])

    -- Initialize default policy tiers
    MySQL.query([[
        INSERT IGNORE INTO insurance_policy_tiers (tier_name, display_name, max_payout, deductible, 
            luxury_coverage, roadside_assistance, rental_reimbursement, medical_coverage, 
            approval_priority, description) VALUES
        ('basic', 'Basic', 5000.00, 1000.00, FALSE, FALSE, FALSE, FALSE, 10,
         'Entry-level coverage. No luxury vehicles, limited payouts, higher deductible.'),
        ('standard', 'Standard', 15000.00, 500.00, FALSE, TRUE, FALSE, FALSE, 5,
         'Standard coverage with medium payouts and roadside assistance.'),
        ('premium', 'Premium', 35000.00, 250.00, TRUE, TRUE, TRUE, TRUE, 3,
         'Premium coverage including luxury vehicles, rental reimbursement, and medical coverage.'),
        ('elite', 'Elite', 100000.00, 100.00, TRUE, TRUE, TRUE, TRUE, 1,
         'Elite coverage with full replacement value, minimal deductible, and priority investigation.')
    ]])

    print('[ai_insurance_adjuster] Database tables initialized successfully.')
end)
