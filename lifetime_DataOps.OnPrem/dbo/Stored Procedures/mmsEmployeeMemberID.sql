


--
-- retrieves all Active Employee's with their MemberID's
--

CREATE     PROCEDURE dbo.mmsEmployeeMemberID
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

   SELECT EmployeeID =
	Case
		When Len(LTrim(RTrim(Cast(EmployeeID as VarChar(15))))) = 1 Then '0000' + Cast(EmployeeID as VarChar(15))
		When Len(LTrim(RTrim(Cast(EmployeeID as VarChar(15))))) = 2 Then '000' + Cast(EmployeeID as VarChar(15))
		When Len(LTrim(RTrim(Cast(EmployeeID as VarChar(15))))) = 3 Then '00' + Cast(EmployeeID as VarChar(15))
		When Len(LTrim(RTrim(Cast(EmployeeID as VarChar(15))))) = 4 Then '0' + Cast(EmployeeID as VarChar(15))
		Else Cast(EmployeeID as VarChar(15))
	End, MemberID
     	FROM dbo.vEmployee
	WHERE ActiveStatusFlag = 1
	ORDER BY EmployeeID

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity


END



