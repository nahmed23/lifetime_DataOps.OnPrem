



--
-- writes the input parameters into an auditing table
--

CREATE   PROC dbo.mmsAuditQuery (
  @Application VARCHAR(50),
  @Document VARCHAR(100),
  @Section VARCHAR(100),
  @Username VARCHAR(50),
  @Parameters VARCHAR(8000),
  @Rows INT,
  @StartDate DATETIME,
  @EndDate DATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

INSERT vAuditQuery ( Application,
       Document,
       Section,
       Username,
       Parameters,
       Rows,
       StartDate,
       EndDate )
VALUES ( @Application,
       @Document,
       @Section,
       @Username,
       @Parameters,
       @Rows,
       @StartDate,
       @EndDate )

SELECT *
  FROM vAuditQuery
 WHERE Section = @Section
       AND StartDate = @StartDate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END




