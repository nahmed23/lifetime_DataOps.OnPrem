

--
-- Returns recordset of Messages by employee for the MemberMessage brio report
--
-- Parameters: an employeeid
--   a start and end open date
-- exec mmsMemberMessage_MessageOpenedBy  '49830', '03/1/2012', '03/15/2012 11:59 PM'
--

CREATE PROC [dbo].[mmsMemberMessage_MessageOpenedBy] (
  @EmployeeID INT,
  @OpenStartDate SMALLDATETIME,
  @OpenEndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

SELECT E.EmployeeID, E.FirstName EmployeeFirstname, E.LastName EmployeeLastname,
       M.MemberID, M.FirstName PrimaryMemberFirstname, M.LastName PrimaryMemberLastname,
       VMGT.Description MessageTypeDescription, MSM.OpenDateTime, MSM.Comment
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vMembershipMessage MSM
       ON MS.MembershipID = MSM.MembershipID
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vEmployee E
       ON MSM.OpenEmployeeID = E.EmployeeID
  LEFT JOIN dbo.vValMembershipMessageType VMGT
       ON MSM.ValMembershipMessageTypeID = VMGT.ValMembershipMessageTypeID
 WHERE E.EmployeeID = @EmployeeID AND
       MSM.OpenDateTime BETWEEN @OpenStartDate AND @OpenEndDate AND
       M.ValMemberTypeID = 1 AND
       VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') 

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END





