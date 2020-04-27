
-- =============================================
-- Object:			dbo.mmsTodaysBusiness_NewMemberships
-- Author:			Susan Myrick (?)
-- Create date: 	
-- Description:		This stored procedure returns data on memberships which expired today
-- Modified date:	12/3/2008 GRB: specifically include membership types instead of excluding
--					certain types; defect 2800 fix to be deployed 12/10/2008 with dbcr_29xx
--					4/2007: users wanted to be able review the full day's business even after
--					midnight, but at that time the report was then displaying only
--					transactions since midnight for the new day. Users decided to start 
--					displaying the new day's transactions only after 6:00 am
-- 	
-- Exec mmsTodaysBusiness_NewMemberships
-- =============================================


CREATE         PROCEDURE [dbo].[mmsTodaysBusiness_NewMemberships]
AS
BEGIN
  SET XACT_ABORT ON
  SET NOCOUNT ON 

  DECLARE @ToDay DATETIME
  DECLARE @Yesterday DATETIME
  DECLARE @ToDayPlus_SixHrs DATETIME
  DECLARE @QueryDateTime DATETIME
  SET @ToDay  = CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102) 
  SET @Yesterday  = DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @ToDayPlus_SixHrs = DATEADD(hh,6, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @QueryDateTime = GETDATE()

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

IF @QueryDateTime >= @ToDayPlus_SixHrs
     
	BEGIN
		SELECT MS.MembershipID,M.MemberID,P.Description AS MembershipTypeDescription,
			 M.FirstName, M.LastName, C.ClubID, C.ClubName,  MS.CreatedDateTime,
			 E.FirstName AdvisorFirstName, E.LastName AdvisorLastName,
			 M.JoinDate,MS.CompanyID,MS.ExpirationDate,E.EmployeeID AdvisorEmployeeID, 
			 CASE
			   WHEN M.EmailAddress IS NULL THEN 0
			   WHEN LTRIM(RTRIM(M.EmailAddress)) = '' THEN 0
			 ELSE 1
			 END Email_OnFile_Flag, @Yesterday AS Yesterday, @QueryDateTime AS QueryDateTime, @Today AS NewMembershipsReportDate
--			,VMTA.Description
		FROM dbo.vClub C 
		JOIN dbo.vMembership MS ON C.ClubID = MS.ClubID
		JOIN dbo.vMember M ON MS.MembershipID = M.MembershipID
		JOIN dbo.vMembershipType MT ON MS.MembershipTypeID = MT.MembershipTypeID
		JOIN dbo.vProduct P ON MT.ProductID = P.ProductID
		JOIN dbo.vEmployee E ON MS.AdvisorEmployeeID = E.EmployeeID
		--	added following two lines 12/3/2008 GRB
		JOIN vMembershipTypeAttribute MTA ON MTA.MembershipTYpeID = MT.MembershipTYpeID
		JOIN vValMembershipTypeAttribute VMTA ON VMTA.ValMembershiptypeAttributeID = MTA.ValMembershiptypeAttributeID

		WHERE M.ValMemberTypeID = 1 AND
			 M.JoinDate = @ToDay AND
		--       P.Description NOT LIKE '%Employee%' AND	--deprecated 12/3/2008 GRB
		--       P.Description NOT LIKE '%Short%'			--deprecated 12/3/2008 GRB
			VMTA.Description IN ('DSSR_Express', 'DSSR_Bronze', 'DSSR_Gold', 'DSSR_Platinum', 'DSSR_Onyx')
	END
ELSE

	BEGIN
		SELECT MS.MembershipID,M.MemberID,P.Description AS MembershipTypeDescription,
			 M.FirstName, M.LastName, C.ClubID, C.ClubName,  MS.CreatedDateTime,
			 E.FirstName AdvisorFirstName, E.LastName AdvisorLastName,
			 M.JoinDate,MS.CompanyID,MS.ExpirationDate,E.EmployeeID AdvisorEmployeeID, 
			 CASE
			   WHEN M.EmailAddress IS NULL THEN 0
			   WHEN LTRIM(RTRIM(M.EmailAddress)) = '' THEN 0
			 ELSE 1
			 END Email_OnFile_Flag, @Yesterday AS Yesterday, @QueryDateTime AS QueryDateTime, @Yesterday AS NewMembershipsReportDate
--		,VMTA.Description
		FROM dbo.vClub C 
		JOIN dbo.vMembership MS ON C.ClubID = MS.ClubID
		JOIN dbo.vMember M ON MS.MembershipID = M.MembershipID
		JOIN dbo.vMembershipType MT ON MS.MembershipTypeID = MT.MembershipTypeID
		JOIN dbo.vProduct P ON MT.ProductID = P.ProductID
		JOIN dbo.vEmployee E ON MS.AdvisorEmployeeID = E.EmployeeID
		--	added following two lines 12/3/2008 GRB
		JOIN vMembershipTypeAttribute MTA ON MTA.MembershipTYpeID = MT.MembershipTYpeID
		JOIN vValMembershipTypeAttribute VMTA ON VMTA.ValMembershiptypeAttributeID = MTA.ValMembershiptypeAttributeID

		WHERE M.ValMemberTypeID = 1 AND
			 M.JoinDate = @Yesterday AND
		--       P.Description NOT LIKE '%Employee%' AND	--deprecated 12/3/2008 GRB
		--       P.Description NOT LIKE '%Short%'			--deprecated 12/3/2008 GRB
			VMTA.Description IN ('DSSR_Express', 'DSSR_Bronze', 'DSSR_Gold', 'DSSR_Platinum', 'DSSR_Onyx')
	END

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
