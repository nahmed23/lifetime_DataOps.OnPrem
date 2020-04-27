
/*    =============================================
    Object:            dbo.mmsMembershipAudit_AuditReport
    Author:            
    Create date:     
    Description:    audit of unauthorized memberships
    Parameters:        ClubIDList        -- Clubname (legacy)
    Modified date:    2/23/2010 GRB: fix QC#4332, omitting 'Corporate Flex' memberships from result set; deploying via dbcr_5721
                    2/2/2010 GRB: fix QC#4273; allow multiple club values to be passed; deploying via dbcr_5620
                    5/23/2011 BSD: added 9 conditions QC#7189
                    6/1/2011 BSD: Added Primary member lastname, firstname, and email address QC#7189
                    10/10/2011 BSD: QC#7929 - excluding ALL flex memberships, added MemberAge column
                    
    EXEC mmsMembershipAudit_AuditReport '194|197|137|203|216|156|168|155|154|193|132|192|1|2|3|4|5|6|7|8|9|10|11|12|133|141|151|164|166|167|170|171|172|173|174|175|176|177|189|204|215'
    =============================================    */

CREATE PROC [dbo].[mmsMembershipAudit_AuditReport] (
    @ClubIDList VARCHAR(8000)        --@ClubName VARCHAR(50)        -- 2/2/2010 GRB
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))                    -- <new code> 2/2/2010 GRB 

--- Parse the ClubIDs into a temp table
CREATE TABLE #Clubs (ClubID VARCHAR(50))
IF @ClubIDList = 'All'
 BEGIN
  INSERT INTO #Clubs SELECT ClubID FROM vClub WHERE DisplayUIFlag = 1
 END
ELSE
 BEGIN
  EXEC procParseStringList @ClubIDList
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList                                            -- </new code> 2/2/2010 GRB 
 END

SELECT ProductID
  INTO #ExcludeProductIDs
  FROM vMembershipType MT
  JOIN vMembershipTypeAttribute MTA
    ON MT.MembershipTypeID = MTA.MembershipTypeID
   AND MTA.ValMembershipTypeAttributeID = 35

SELECT M.MembershipID, M.MemberID, M.FirstName,
       M.LastName, M.ValMemberTypeID, M.DOB, C.ClubName,
       P.Description AS MembershipTypeDescription, 
       VR.Description AS RegionDescription,
       VMT.Description AS MemberTypeDescription, 
       VMSTFS.Description AS MembershipSizeDescription,
       M2.LastName PrimaryMemberLastName,    --6/1/2011 BSD
       M2.FirstName PrimaryMemberFirstName,    --6/1/2011 BSD
       M2.EmailAddress PrimaryMemberEmailAddress,    --6/1/2011 BSD
       Convert(Varchar,DATEDIFF(yy,M.DOB,GETDATE()) - CASE WHEN DATEPART(dy,M.DOB) > DATEPART(dy,getdate()) THEN 1 ELSE 0 END) MemberAgeInYears, --10/10/2011 BSD
       CASE MCP.ActiveFlag WHEN 1 THEN 'Do Not Solicit' ELSE '' END DoNotMailFlag,
       MA.AddressLine1,
       MA.AddressLine2,
       MA.City,
       VS.Abbreviation State,
       MA.Zip,
       VC.Abbreviation Country
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
    ON M.MembershipID = MS.MembershipID
  JOIN dbo.vMembershipType MST
    ON MS.MembershipTypeID = MST.MembershipTypeID    
  JOIN dbo.vProduct P
    ON MST.ProductID = P.ProductID
  JOIN dbo.vClub C
    ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
    ON C.ClubID = CS.ClubID
  JOIN dbo.vValMembershipStatus VMSS
    ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN dbo.vValRegion VR
    ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vValMemberType VMT
    ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vValMembershipTypeFamilyStatus VMSTFS 
    ON VMSTFS.ValMembershipTypeFamilyStatusID = MST.ValMembershipTypeFamilyStatusID
  JOIN dbo.vMember M2
    ON MS.MembershipID = M2.MembershipID
  LEFT JOIN vMembershipAddress MA
    ON M2.MembershipID = MA.MembershipID
   AND MA.ValAddressTypeID = 1
  LEFT JOIN vValState VS
    ON MA.ValStateID = VS.ValStateID
  LEFT JOIN vValCountry VC
    ON MA.ValCountryID = VC.ValCountryID
  LEFT JOIN vMembershipCommunicationPreference MCP
    ON M2.MembershipID = MCP.MembershipID
   AND MCP.ValCommunicationPreferenceID = 1
 WHERE VMSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended')
   AND M.ActiveFlag = 1
   AND M2.ValMemberTypeID = 1
   AND MST.ProductID NOT IN (SELECT ProductID FROM #ExcludeProductIDs)
/****  Added 5/23/2011 BSD *****/
   AND ((VMT.Description = 'Junior' AND Datediff(mm,M.DOB,GetDate()) >= 141 AND Datediff(mm,M.DOB,GetDate()) <= 142)
        OR (VMT.Description = 'Secondary' AND Datediff(mm,M.DOB,GetDate()) >= 249 AND Datediff(mm,M.DOB,GetDate()) <= 250)
        OR (VMT.Description = 'Junior' AND Datediff(mm,M.DOB,GetDate()) > 142 AND Datediff(mm,M.DOB,GetDate()) < 144)
        OR (VMT.Description = 'Secondary' AND Datediff(mm,M.DOB,GetDate()) > 250 AND Datediff(mm,M.DOB,GetDate()) < 252)
        OR (VMT.Description = 'Junior' AND Datediff(mm,M.DOB,GetDate()) >= 144)
        OR (VMT.Description = 'Secondary' AND Datediff(mm,M.DOB,GetDate()) >= 252)
        OR (VMT.Description = 'Secondary' AND Substring(VMSTFS.Description,1,6) = 'Single')
        OR (VMT.Description <> 'Junior' AND Substring(VMSTFS.Description,1,6) = 'Couple')
        OR (VMT.Description = 'Partner' AND Substring(VMSTFS.Description,1,6) = 'Single' ))
/********************************/

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity
       
END

