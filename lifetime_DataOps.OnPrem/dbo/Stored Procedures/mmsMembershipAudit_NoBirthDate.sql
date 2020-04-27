
/*	=============================================
	Object:			dbo.mmsMembershipAudit_NoBirthDate
	Author:			
	Create date: 	
	Description:	MembershipAudit bqy;  looking for Secondary & Partner Members with no birth date entered in system
	Parameters:		ClubIDList		-- Clubname (legacy)
	Modified date:	2/2/2010 GRB: fix QC#4273; allow multiple club values to be passed; deploying via dbcr_5620
					
	EXEC mmsMembershipAudit_NoBirthDate '131|144|21|126|22|20'
	=============================================	*/

CREATE  PROC [dbo].[mmsMembershipAudit_NoBirthDate] (
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

SELECT M.MembershipID, M.MemberID, M.ValMemberTypeID,
       M.DOB, M.ActiveFlag, C.ClubName,
       VMSS.Description AS MembershipStatusDescription, 
       VR.Description AS RegionDescription, 
       M2.MemberID AS PrimaryMemberID, 
       M2.FirstName AS PrimaryFirstName, M2.LastName AS PrimaryLastName, 
       VMT.Description AS MemberTypeDescription
  FROM dbo.vMember M
  JOIN dbo.vMember M2
       ON M.MembershipID = M2.MembershipID
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS												-- <new code> 2/2/2010 GRB 
       ON C.ClubID = CS.ClubID									-- </new code> 2/2/2010 GRB 
  JOIN dbo.vValMembershipStatus VMSS
       ON VMSS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vValMemberType VMT 
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
 WHERE M.DOB IS NULL AND
--     C.ClubName = @ClubName AND								-- 2/2/2010 GRB
       VMT.Description IN ('Junior', 'Secondary') AND
       M.ActiveFlag = 1 AND
       VMSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') AND
       M2.ValMemberTypeID = 1

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
