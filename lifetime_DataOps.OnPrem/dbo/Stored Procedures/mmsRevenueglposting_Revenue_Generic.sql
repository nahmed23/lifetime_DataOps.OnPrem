
--
-- Returns a set of tran records for the Revenueglposting report
-- 
-- Parameters: Transaction Types includes Adjustment, Charge, and Refund.
--             Take a string of comma separated ClubIDs.
----           also, the transactions are only coming from closed drawers.

CREATE   PROC dbo.mmsRevenueglposting_Revenue_Generic(
             @ClubList VARCHAR(1000))
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #ClubID(ClubID VARCHAR(15))
EXEC procParseClubIDs @ClubList

SELECT TI.ItemAmount, D.Description DeptDescription, P.Description ProductDescription, 
       C2.ClubName MembershipClubname, MMST.DrawerActivityID, MMST.PostDateTime, 
       MMST.TranDate, MMST.ValTranTypeID, MMST.MemberID, 
       TI.ItemSalesTax, MMST.EmployeeID, M.FirstName MemberFirstname, 
       M.LastName MemberLastname, TI.TranItemID, M.JoinDate TranMemberJoinDate, 
       MMST.MembershipID, P.ValGLGroupID, P.GLAccountNumber, 
       P.GLSubAccountNumber, P.GLOverRideClubID, P.ProductID, 
       VGLG.Description GLGroupIDDescription, C1.GLTaxID, C1.GLClubID Posting_GLClubid, 
       VR.Description Posting_RegionDescription, C1.ClubName Posting_Clubname, C1.ClubID Posting_MMSClubid, 
       E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, 
       MMST4.Description TransactionDescription, VTT.Description TranTypeDescription 
  FROM dbo.vMMSTran MMST
  JOIN dbo.vClub C1
       ON C1.ClubID = MMST.ClubID
  JOIN dbo.vValRegion VR
       ON C1.ValRegionID = VR.ValRegionID
  JOIN dbo.vTranItem TI
       ON TI.MMSTranID = MMST.MMSTranID
  JOIN dbo.vProduct P
       ON P.ProductID = TI.ProductID
  JOIN dbo.vDepartment D
       ON D.DepartmentID = P.DepartmentID
  JOIN dbo.vMembership MS
       ON MS.MembershipID = MMST.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValTranType VTT
       ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValGLGroup VGLG
       ON P.ValGLGroupID = VGLG.ValGLGroupID
  JOIN dbo.vEmployee E
       ON MMST.EmployeeID = E.EmployeeID
  JOIN dbo.vReasonCode MMST4
       ON MMST4.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vDrawerActivity DA 
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  JOIN #ClubID C3
       ON C3.ClubID = C1.ClubID
 WHERE DATEDIFF(month,MMST.PostDateTime,GETDATE()) = 1 AND
       VTT.ValTranTypeID IN (1,3,4,5) AND  
       MMST.TranVoidedID IS NULL AND 
       DA.ValDrawerStatusID = 3
       
UNION

SELECT TI.ItemAmount, D.Description DeptDescription, P.Description ProductDescription, 
       C2.ClubName MembershipClubname, MMST.DrawerActivityID, MMST.PostDateTime, 
       MMST.TranDate, MMST.ValTranTypeID, MMST.MemberID, 
       TI.ItemSalesTax, MMST.EmployeeID, M.FirstName MemberFirstname, 
       M.LastName MemberLastname, TI.TranItemID, M.JoinDate TranMemberJoinDate, 
       MMST.MembershipID, P.ValGLGroupID, P.GLAccountNumber, 
       P.GLSubAccountNumber, P.GLOverRideClubID, P.ProductID, 
       VGLG.Description GLGroupIDDescription, C2.GLTaxID, C2.GLClubID, 
       VR.Description Posting_RegionDescription, C2.ClubName Posting_Clubname, C2.ClubID Posting_MMSClubid, 
       E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, 
       RC.Description TransactionDescription, VTT.Description TranTypeDescription
  FROM dbo.vMMSTran MMST
  JOIN dbo.vClub C1
       ON C1.ClubID = MMST.ClubID
  JOIN dbo.vTranItem TI
       ON TI.MMSTranID = MMST.MMSTranID
  JOIN dbo.vProduct P
       ON P.ProductID = TI.ProductID
  JOIN dbo.vDepartment D
       ON D.DepartmentID = P.DepartmentID
  JOIN dbo.vMembership MS
       ON MS.MembershipID = MMST.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValRegion VR
       ON C2.ValRegionID = VR.ValRegionID
  JOIN dbo.vValTranType VTT
       ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValGLGroup VGLG
       ON P.ValGLGroupID = VGLG.ValGLGroupID
  JOIN dbo.vEmployee E
       ON MMST.EmployeeID = E.EmployeeID
  JOIN dbo.vReasonCode RC
       ON RC.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vDrawerActivity DA 
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  JOIN #ClubID C3
       ON C3.ClubID = C2.ClubID
 WHERE C1.ClubID = 13 AND 
       VTT.ValTranTypeID IN (1,3,4,5) AND 
       MMST.TranVoidedID IS NULL AND 
       DATEDIFF(month,MMST.PostDateTime,GETDATE()) = 1 AND 
       DA.ValDrawerStatusID = 3

DROP TABLE #ClubID

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



