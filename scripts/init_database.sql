/*

====================================================
CREATE DATABASE AND SCHEMAS
====================================================

Script Purpose:
	This script creates a new database named DataWarehouse after checking if it exists.
	If the database already exists, it will be dropped and recreated.
	This script also creates the 'bronze', 'silver', and 'gold' schemas within the DataWarehouse database.

WARNING:
	Running this script will result in permanent loss of all data in the 'DataWarehouse' database if it already exists.
	Ensure that you have backed up any important data before executing this script.

*/

USE master;
GO

-- Drop the DataWarehouse database if it already exists
IF EXISTS( SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse' )
BEGIN
	ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE DataWarehouse;
END;
GO

-- Create the DataWarehouse database
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- Create Schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO

