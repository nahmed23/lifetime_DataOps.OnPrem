




--
-- Returns recordset of Messages by employee for the MemberMessage brio report
--
-- Parameters: the first portion of an employees firstname
--    the first portion of an employees lastname
--

CREATE PROC dbo.mmsMemberMessage_EmployeeIDSearch (
  @FirstName VARCHAR(50),
  @LastName VARCHAR(50)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

 -- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT E.FirstName [First Name], E.LastName [Last Name], E.EmployeeID [Employee ID]
  FROM dbo.vEmployee E
 WHERE E.FirstName LIKE @FirstName + '%' AND 
       E.LastName LIKE @LastName + '%'
 ORDER BY E.FirstName, E.LastName

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END





