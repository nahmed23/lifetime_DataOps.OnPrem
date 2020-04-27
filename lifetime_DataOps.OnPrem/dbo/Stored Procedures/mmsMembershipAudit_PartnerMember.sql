
/*	=============================================
	Object:			dbo.mmsMembershipAudit_PartnerMember
	Author:			
	Create date: 	
	Description:	looking for partner memberships that need to be updated to new type of membership
	Parameters:		ClubIDList		-- Clubname (legacy)
	Modified date:	2/2/2010 GRB: fix QC#4273; allow multiple club values to be passed; deploying via dbcr_5620
					
	EXEC mmsMembershipAudit_PartnerMember '131|144|21|126|22|20'
	=============================================	*/

CREATE PROC [dbo].[mmsMembershipAudit_PartnerMember] (
	@ClubIDList VARCHAR(8000)		--@ClubName VARCHAR(50)		-- 2/2/2010 GRB
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))					-- <new code> 2/2/2010 GRB 

--- Parse the ClubIDs into a temp table
CREATE TABLE #Clubs (ClubID VARCHAR(50))
EXEC procParseStringList @ClubIDList
INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList											-- </new code> 2/2/2010 GRB 

SELECT C.ClubName, MS.MembershipID, M.MemberID,
       M.FirstName, M.LastName, M.DOB,
       M.ActiveFlag, 
       VR.Description AS RegionDescription, 
       P.Description AS MembershipTypeDescription,
       VMT.Description AS MemberTypeDescription, 
       VMSTFS.Description AS MembershipSizeDescription
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID     
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS												-- <new code> 2/2/2010 GRB 
       ON C.ClubID = CS.ClubID									-- </new code> 2/2/2010 GRB 
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vValMembershipTypeFamilyStatus VMSTFS
       ON VMSTFS.ValMembershipTypeFamilyStatusID = MST.ValMembershipTypeFamilyStatusID
  JOIN dbo.vValMembershipStatus VMSS 
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
 WHERE VMT.Description = 'Partner' AND
       M.ActiveFlag = 1 AND
--     C.ClubName = @ClubName AND								-- 2/2/2010 GRB
       VMSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended')

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
