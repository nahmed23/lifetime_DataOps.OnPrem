
/*	=============================================
	Object:			dbo.mmsMembershipAudit_JuniorMember
	Author:			
	Create date: 	
	Description:	looking for junior memberships that are turning of age and need membership update
	Parameters:		ClubIDList		-- Clubname (legacy)
	Modified date:	2/2/2010 GRB: fix QC#4273; allow multiple club values to be passed; deploying via dbcr_5620
					
	EXEC mmsMembershipAudit_JuniorMember '131|144|21|126|22|20'
	=============================================	*/

CREATE  PROC [dbo].[mmsMembershipAudit_JuniorMember] (
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

SELECT C.ClubName, MS.MembershipID, M2.MemberID,
       M2.FirstName, M2.LastName, M2.DOB,
       M2.ActiveFlag, M.FirstName AS AddressFirstName, M.LastName AS AddressLastName,
       MSA.AddressLine1, MSA.AddressLine2, MSA.City, MSA.Zip,
       VR.Description AS RegionDescription, 
       P.Description AS MembershipTypeDescription,
       VS.Abbreviation AS StateAbbreviation, 
       VC.Abbreviation AS CountryAbbreviation
  FROM dbo.vMember M2
  JOIN dbo.vMembership MS
       ON M2.MembershipID = MS.MembershipID
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
       ON M2.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
 RIGHT OUTER JOIN dbo.vMember M
       ON M2.MembershipID = M.MembershipID
  JOIN dbo.vMembershipAddress MSA 
       ON M.MembershipID = MSA.MembershipID
  LEFT JOIN dbo.vValState VS
       ON (VS.ValStateID = MSA.ValStateID)
  LEFT JOIN dbo.vValCountry VC
       ON (VC.ValCountryID = MSA.ValCountryID) 
 WHERE VMT.Description = 'Junior' AND
       M2.ActiveFlag = 1 AND
       M.ValMemberTypeID = 1 AND
--     C.ClubName = @ClubName AND								-- 2/2/2010 GRB
       VMSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended')

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
