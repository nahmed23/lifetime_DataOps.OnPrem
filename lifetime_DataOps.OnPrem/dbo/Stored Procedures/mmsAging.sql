





-- retrieves balance for mac report
-- not anticipated for other clubs, so club is hardcoded

CREATE  PROC dbo.mmsAging

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT TB.MembershipID, MMST.TranDate, TB.TranBalanceAmount,
       C.ClubName, P.Description AS ProductDescription, MSB.StatementDateTime
  FROM dbo.vTranBalance TB
  JOIN dbo.vTranItem TI
       ON TB.TranItemID = TI.TranItemID
  JOIN dbo.vMMSTran MMST
       ON TI.MMSTranID = MMST.MMSTranID
  JOIN dbo.vMembership MS
       ON MS.MembershipID = TB.MembershipID     
  JOIN dbo.vClub C
       ON C.ClubID = MS.ClubID
  JOIN dbo.vMembershipBalance MSB
       ON MMST.MembershipID = MSB.MembershipID
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN dbo.vDrawerActivity DA
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  LEFT JOIN dbo.vProduct P
       ON (P.ProductID = TI.ProductID) 
 WHERE C.ClubName = 'Minneapolis Athletic Club' AND
       TB.TranBalanceAmount<>0 AND
       DA.CloseDateTime< = MSB.StatementDateTime AND
       VMSS.Description IN ('Active', 'Pending Termination', 'Suspended') AND
       C.ValStatementTypeID = 2
 ORDER BY TB.MembershipID

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END






