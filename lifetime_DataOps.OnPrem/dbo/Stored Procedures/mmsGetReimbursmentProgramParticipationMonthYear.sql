
CREATE PROCEDURE mmsGetReimbursmentProgramParticipationMonthYear AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

SELECT ReimbursementProgramID,
       MonthYear, 
       YearMonth,
       InsertedDate, 
       SUBSTRING(YearMonth,1,4) AS Year,
       SUBSTRING(MonthYear,1,(LEN(MonthYear)- 6)) AS Month
  FROM vReimbursementProgramParticipationDetail
 GROUP BY ReimbursementProgramID,
       MonthYear, 
       YearMonth, 
       InsertedDate
 ORDER BY ReimbursementProgramID

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

