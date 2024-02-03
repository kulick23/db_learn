-- Creating a new user with the ability to connect to the database
CREATE USER rentaluser WITH PASSWORD 'rentalpassword';
GRANT CONNECT ON DATABASE dvdrental1 TO rentaluser;

-- Granting SELECT permission for the "customer" table to the user "rentaluser"
GRANT SELECT ON TABLE customer TO rentaluser;

-- Checking SELECT permissions for "rentaluser"
SET ROLE rentaluser;
SELECT * FROM customer;
RESET ROLE;

-- Creating a new group named "rental" and adding "rentaluser" to the group
CREATE GROUP rental;
ALTER GROUP rental ADD USER rentaluser;

-- Granting INSERT and UPDATE permissions for the "rental" table to the "rental" group
GRANT INSERT, UPDATE ON TABLE rental TO rental;
GRANT USAGE, SELECT ON SEQUENCE rental_rental_id_seq TO rental;

-- Inserting a new row and updating an existing row in the "rental" table on behalf of "rentaluser"
SET ROLE rentaluser;
SHOW ROLE;
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
VALUES (CURRENT_DATE, 123, 456, CURRENT_DATE, 5, NOW());

UPDATE rental SET return_date = CURRENT_DATE WHERE rental_id = 1;
RESET ROLE;

-- Revoking INSERT permission for the "rental" table from the "rental" group
REVOKE INSERT ON TABLE rental FROM rental;

-- Attempting to insert new rows into the "rental" table (should be denied)
SET ROLE rentaluser;
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
VALUES (CURRENT_DATE, 234, 567, CURRENT_DATE, 890, NOW());
RESET ROLE;

-- Creating a personalized role for any existing customer in the dvd_rental database
-- The role name should be client_{first_name}_{last_name} (omit curly brackets)
-- The customer's payment and rental history must not be empty
-- Configuring the role to allow access only to the customer's own data in the "rental" and "payment" tables
-- Writing a query to ensure the user sees only their own data

CREATE OR REPLACE FUNCTION set_new_user_role()
RETURNS TEXT
LANGUAGE plpgsql AS $$
DECLARE
  new_customer_id INT;
  new_username TEXT;
BEGIN
  -- Getting information about the customer
  SELECT c.customer_id INTO new_customer_id
  FROM customer c
  JOIN rental r ON c.customer_id = r.customer_id
  JOIN payment p ON c.customer_id = p.customer_id
  GROUP BY c.customer_id, c.first_name, c.last_name
  HAVING COUNT(DISTINCT r.rental_id) > 0 AND COUNT(DISTINCT p.payment_id) > 0
  LIMIT 1;

  -- Generating the role name
  SELECT CONCAT('client_', c.first_name, '_', c.last_name) INTO new_username
  FROM customer c
  WHERE c.customer_id = new_customer_id;

  -- Converting the username to lowercase
  new_username := LOWER(new_username);

  -- Checking if the role already exists
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = new_username) THEN
    -- Creating a new role
    EXECUTE FORMAT('CREATE ROLE %I', new_username);

    -- Granting various permissions for the new role
    EXECUTE FORMAT('GRANT CONNECT ON DATABASE dvdrental1 TO %I', new_username);
    EXECUTE FORMAT('GRANT SELECT ON TABLE rental TO %I', new_username);
    EXECUTE FORMAT('GRANT SELECT ON TABLE payment TO %I', new_username);
    
    -- Enabling ROW LEVEL SECURITY
    ALTER TABLE rental ENABLE ROW LEVEL SECURITY;
    ALTER TABLE payment ENABLE ROW LEVEL SECURITY;

    -- Creating security policies for the new role
    EXECUTE FORMAT('CREATE POLICY new_user_policy_on_rental
      ON rental
      FOR SELECT
      TO %I
      USING (customer_id = %L)', new_username, new_customer_id);
      
    EXECUTE FORMAT('CREATE POLICY new_user_policy_on_payment
      ON payment
      FOR SELECT
      TO %I
      USING (customer_id = %L)', new_username, new_customer_id);

    -- Enabling ROW LEVEL SECURITY for tables
    ALTER TABLE rental ENABLE ROW LEVEL SECURITY;
    ALTER TABLE payment ENABLE ROW LEVEL SECURITY;
  END IF;

  -- Setting the new role
  EXECUTE 'SET ROLE ' || new_username;

  RETURN new_username;
END $$;

-- Calling the function to create a personalized role and checking permissions
SELECT set_new_user_role();

-- Checking that the new role sees only its own data
SELECT * FROM rental;
SELECT * FROM payment;

-- Resetting the current role
RESET ROLE;


