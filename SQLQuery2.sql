CREATE DATABASE OTTStreamingDB;
GO
USE OTTStreamingDB;
GO

-- SAFETY CHECK
DROP TABLE IF EXISTS Fact_StreamingLogs;
DROP TABLE IF EXISTS Dim_Customer;
DROP TABLE IF EXISTS Dim_Content;
DROP TABLE IF EXISTS Dim_ISP;
GO

-- 1. Create Dimension Tables
CREATE TABLE Dim_Customer (
    CustomerID INT PRIMARY KEY,
    SubscriptionTier VARCHAR(50), -- Mobile, Premium, 4K
    City VARCHAR(50),
    DeviceType VARCHAR(50) -- Smart TV, Mobile, Laptop
);

CREATE TABLE Dim_Content (
    ContentID INT PRIMARY KEY,
    Title VARCHAR(100),
    ContentType VARCHAR(50), -- Live Sports, Movie, Web Series
    BaseResolution VARCHAR(20) -- 1080p, 4K
);

CREATE TABLE Dim_ISP (
    ISPID INT PRIMARY KEY,
    ProviderName VARCHAR(50),
    NetworkType VARCHAR(50) -- Fiber, 4G, 5G
);

-- 2. Create Fact Table (Streaming Logs & Quality)
CREATE TABLE Fact_StreamingLogs (
    StreamID INT IDENTITY(10001,1) PRIMARY KEY,
    CustomerID INT FOREIGN KEY REFERENCES Dim_Customer(CustomerID),
    ContentID INT FOREIGN KEY REFERENCES Dim_Content(ContentID),
    ISPID INT FOREIGN KEY REFERENCES Dim_ISP(ISPID),
    StreamDateTime DATETIME,
    StreamDuration_Mins INT,
    AverageBitrate_Kbps INT,
    BufferingEvents INT,
    IsPlaybackSuccessful INT, -- 1 = Success, 0 = Failed/Crashed
    CSAT_Score INT -- Customer Satisfaction (1 to 5)
);

-- 3. Insert Realistic OTT Dimension Data
INSERT INTO Dim_Customer VALUES 
(1, 'Premium 4K', 'Mumbai', 'Smart TV'), (2, 'Mobile Only', 'Patna', 'Mobile'),
(3, 'Standard HD', 'Bengaluru', 'Laptop'), (4, 'Premium 4K', 'Delhi', 'Smart TV'),
(5, 'Mobile Only', 'Lucknow', 'Mobile');

INSERT INTO Dim_Content VALUES 
(1, 'IPL Final 2025', 'Live Sports', '1080p'), (2, 'Bollywood Blockbuster', 'Movie', '4K'),
(3, 'Crime Thriller S1', 'Web Series', '1080p'), (4, 'World Cup Semi-Final', 'Live Sports', '1080p'),
(5, 'Standup Comedy Special', 'Movie', '1080p');

INSERT INTO Dim_ISP VALUES 
(1, 'JioFiber', 'Fiber'), (2, 'Airtel Xstream', 'Fiber'), 
(3, 'Vi LTE', '4G'), (4, 'Jio True5G', '5G'), (5, 'BSNL Broadband', 'DSL');

-- 4. Generate 2,000 Streaming Sessions
INSERT INTO Fact_StreamingLogs (CustomerID, ContentID, ISPID, StreamDateTime, StreamDuration_Mins)
SELECT 
    (ABS(CHECKSUM(NEWID())) % 5) + 1,  -- Customer 1-5
    (ABS(CHECKSUM(NEWID())) % 5) + 1,  -- Content 1-5
    (ABS(CHECKSUM(NEWID())) % 5) + 1,  -- ISP 1-5
    DATEADD(MINUTE, -(ABS(CHECKSUM(NEWID())) % 43200), GETDATE()), -- Last 30 days
    (ABS(CHECKSUM(NEWID())) % 160) + 20; -- Duration 20 to 180 mins
GO 2000

-- 5. Build Realistic Network & Buffering Logic!
-- Default successful playbacks with 0 or 1 buffering events
UPDATE Fact_StreamingLogs 
SET BufferingEvents = (ABS(CHECKSUM(NEWID())) % 2), IsPlaybackSuccessful = 1, CSAT_Score = 5, AverageBitrate_Kbps = 4500;

-- LOGIC 1: 'Live Sports' puts massive load on servers, causing high buffering
UPDATE Fact_StreamingLogs 
SET BufferingEvents = (ABS(CHECKSUM(NEWID())) % 8) + 3, AverageBitrate_Kbps = 1500
WHERE ContentID IN (1, 4) AND (ABS(CHECKSUM(NEWID())) % 10) > 4;

-- LOGIC 2: 4G and DSL connections experience more buffering than Fiber/5G
UPDATE Fact_StreamingLogs 
SET BufferingEvents = BufferingEvents + 2, AverageBitrate_Kbps = 1200 
WHERE ISPID IN (3, 5);

-- LOGIC 3: Playback Fails if Buffering Events exceed 7
UPDATE Fact_StreamingLogs 
SET IsPlaybackSuccessful = 0, StreamDuration_Mins = (ABS(CHECKSUM(NEWID())) % 5) + 1 
WHERE BufferingEvents >= 7;

-- LOGIC 4: Customer Satisfaction (CSAT) crashes if buffering is high!
UPDATE Fact_StreamingLogs SET CSAT_Score = 4 WHERE BufferingEvents BETWEEN 2 AND 4;
UPDATE Fact_StreamingLogs SET CSAT_Score = 2 WHERE BufferingEvents BETWEEN 5 AND 6;
UPDATE Fact_StreamingLogs SET CSAT_Score = 1 WHERE BufferingEvents >= 7 OR IsPlaybackSuccessful = 0;