


--
-- Returns active membership phone numbers

CREATE     PROC dbo.mmsMembershipPhoneNumbers
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

Select (MP.AreaCode + MP.Number) AS MemberPhone
	From dbo.vMembershipPhone MP
	Join dbo.vMembership MS
       		ON MP.MembershipID = MS.MembershipID
Where MS.ExpirationDate Is Null

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



