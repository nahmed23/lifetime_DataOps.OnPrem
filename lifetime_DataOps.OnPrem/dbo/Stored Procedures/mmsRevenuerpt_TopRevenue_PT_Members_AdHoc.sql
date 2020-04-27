







--
-- Ad Hoc created for Mark Thom to analyze top revenue memberships in PT 
-- 
----Exec mmsRevenuerpt_TopRevenue_PT_Members_AdHoc

CREATE             PROC dbo.mmsRevenuerpt_TopRevenue_PT_Members_AdHoc 

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

          SELECT C2.ClubName PostingClubName, Sum(TI.ItemAmount), D.Description DeptDescription,
                 P.Description ProductDescription, C.ClubName MembershipClubname, MMST.ClubID PostingClubid,
                 VTT.Description TranTypeDescription, MMST.ValTranTypeID, MMST.MemberID,
                 VR.Description PostingRegionDescription,
                 M.FirstName MemberFirstname, M.LastName MemberLastname,
                 M.JoinDate TranMemberJoinDate, MMST.MembershipID, P.ProductID, MMST.ClubID TranClubid,VMS.Description AS Status 
               FROM dbo.vMMSTran MMST 
               JOIN dbo.vClub C2
                 ON C2.ClubID = MMST.ClubID
               JOIN dbo.vValRegion VR
                 ON C2.ValRegionID = VR.ValRegionID
               JOIN dbo.vTranItem TI
                 ON TI.MMSTranID = MMST.MMSTranID
               JOIN dbo.vProduct P
                 ON P.ProductID = TI.ProductID
               JOIN dbo.vDepartment D
                 ON D.DepartmentID = P.DepartmentID
               JOIN dbo.vMembership MS
                 ON MS.MembershipID = MMST.MembershipID
               JOIN dbo.vClub C
                 ON MS.ClubID = C.ClubID
               JOIN dbo.vValTranType VTT
                 ON MMST.ValTranTypeID = VTT.ValTranTypeID
               JOIN dbo.vMember M
                 ON M.MemberID = MMST.MemberID
               JOIN vValMembershipStatus VMS
                 ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
          WHERE MMST.PostDateTime >= '01/01/01' AND
                MMST.PostDateTime < '01/01/02' AND
                MMST.TranVoidedID IS NULL AND
                VTT.ValTranTypeID IN (1, 3, 4, 5) AND
                C2.DisplayUIFlag = 1 AND
                ----M.MemberID = 100909332 AND
                D.Description in('Personal Training','Nutrition Coaching','Merchandise','Mind Body')
                ----D.Description = 'Member Programming'
                Group By C2.ClubName,D.Description,P.Description,C.ClubName,MMST.ClubID,VTT.Description,MMST.ValTranTypeID,
                MMST.MemberID,VR.Description,M.FirstName,M.LastName,M.JoinDate,MMST.MembershipID,P.ProductID,
                MMST.ClubID,VMS.Description

          UNION ALL

	  SELECT C2.ClubName PostingClubName, Sum(TI.ItemAmount), D.Description DeptDescription,
	         P.Description ProductDescription, C2.ClubName MembershipClubname, C2.ClubID PostingClubid,
                 VTT.Description TranTypeDescription,
	         MMST.ValTranTypeID, M.MemberID, 
	         VR.Description PostingRegionDescription, M.FirstName MemberFirstname, M.LastName MemberLastname,
                 M.JoinDate TranMemberJoinDate, MMST.MembershipID,
	         P.ProductID, MMST.ClubID TranClubid, VMS.Description AS Status 
	  FROM dbo.vMMSTran MMST
	       JOIN dbo.vClub C
	         ON C.ClubID = MMST.ClubID
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
               JOIN vValMembershipStatus VMS
                 ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
	  WHERE C.ClubID = 13 AND
	      MMST.PostDateTime >= '01/01/01' AND
	      MMST.PostDateTime < '01/01/02' AND
	      VTT.ValTranTypeID IN (1, 3, 4, 5) AND
	      MMST.TranVoidedID IS NULL AND
              -----M.MemberID = 100909332 AND
              D.Description in('Personal Training','Nutrition Coaching','Merchandise','Mind Body')
              ----D.Description = 'Member Programming'
              Group By C2.ClubName,D.Description,P.Description,C2.ClubName,C2.ClubID,VTT.Description,MMST.ValTranTypeID,
                M.MemberID,VR.Description,M.FirstName,M.LastName,M.JoinDate,MMST.MembershipID,P.ProductID,
                MMST.ClubID,VMS.Description


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END








