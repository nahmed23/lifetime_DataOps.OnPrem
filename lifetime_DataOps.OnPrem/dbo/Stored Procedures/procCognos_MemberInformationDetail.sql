


--------  Sample execution
----  exec procCognos_MemberInformationDetail 'Non-Terminated','Hall-MN-West', 'All Clubs', '2/1/2014', '2/28/2014', 'Primary|Partner|Secondary|Junior'
--------

CREATE PROC [dbo].[procCognos_MemberInformationDetail] (
  @TerminatedOrNonTerminated VARCHAR(50),
  @RegionList VARCHAR(2000),
  @ClubIDList VARCHAR(2000),
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME,
  @MemberTypeList VARCHAR(1000)  
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @HeaderMemberTypeList AS VARCHAR(200)
DECLARE @ReportRunDateTime VARCHAR(21) 
DECLARE @HeaderDateRange VARCHAR(33)

SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')
SET @HeaderMemberTypeList = REPLACE(@MemberTypeList, '|', ', ') 
SET @HeaderDateRange = convert(varchar(12), @StartDate, 107) + ' to ' + convert(varchar(12), @EndDate, 107)

IF NOT @TerminatedOrNonTerminated IN ('Terminated', 'Non-Terminated')
BEGIN
  RAISERROR('Parameter @TerminatedOrNonTerminated expects either ''Terminated'' or ''Non-Terminated''', 16, 1)
  RETURN
END


CREATE TABLE #tmpList (StringField VARCHAR(20))

   SELECT DISTINCT Club.ClubID 
  INTO #Clubs
  FROM vClub Club
  JOIN fnParsePipeList(@ClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @ClubIDList like '%All Clubs%'
  JOIN vValRegion ValRegion
    ON Club.ValRegionID = ValRegion.ValRegionID
  JOIN fnParsePipeList(@RegionList) RegionList
    ON ValRegion.Description = RegionList.Item
      OR @RegionList like '%All Regions%'

CREATE TABLE #MemberTypes (MemberType VARCHAR(50))
  EXEC procParseStringList @MemberTypeList
  INSERT INTO #MemberTypes (MemberType) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

IF @TerminatedOrNonTerminated = 'Terminated'

SELECT VR.Description RegionDescription, 
       C.DomainNamePrefix, 
       C.ClubName,
       M.MemberID, M.FirstName, M.LastName, M.JoinDate,
       MS.CreatedDateTime, 
       VPT.Description PhoneTypeDescription, 
       MSP.AreaCode,
       MSP.Number, 
       MS.MembershipID, 
       VMS.Description MembershipStatusDescription,
       P.ProductID, 
       P.Description ProductDescription, 
       M.DOB,
       DATEDIFF ( year, M.DOB, GETDATE() ) Age,
       VMT.Description MemberTypeDescription, MA.AddressLine1, MA.AddressLine2, MA.City, VS.Abbreviation StateAbbreviation, MA.Zip,
       VC.Abbreviation CountryAbbreviation, 
       GETDATE() QueryDate, 
       M.Gender,
       VMT.SortOrder MemberTypeSortOrder, 
       MS.CompanyID, 
       CO.CompanyName,
       CO.CorporateCode, 
       MTFS.Description MembershipSizeDescription,
       MS.ExpirationDate, 
       VTR.Description TermReasonDescription,
       CASE WHEN MS.CompanyID IS NULL THEN 0 ELSE 1 END AS CorpAffiliationFlag, 
       CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END AS  MembershipCreateDate,     
       CONVERT(DECIMAL(5,1),                     
       CASE WHEN MS.ExpirationDate IS NULL 
            THEN DATEDIFF(MONTH,CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END, GETDATE())  / 12.0
            ELSE DATEDIFF(MONTH,CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END, Expirationdate )/12.0  
            END) AS MembershipLengthYears, 
       SUBSTRING(DATENAME(mm,CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END),1,3) AS MembershipCreateDateMonth,
       'Q' + CONVERT(VARCHAR(2),DATEPART(QQ, CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END)) AS MembershipCreateDateQuarter,                 
       DATEPART(YEAR, CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END) AS MembershipCreateDateYear,
       @TerminatedOrNonTerminated AS HeaderMembershipStatus,
       @HeaderMemberTypeList AS HeaderMemberType,
       @ReportRunDateTime AS ReportRunDateTime,
       @HeaderDateRange AS HeaderDateRange
                  
       --CASE WHEN MS.ExpirationDate IS NULL 
       --     THEN CASt(DATEDIFF(MONTH,CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END, GETDATE()) AS decimal(7,1))
       --     ELSE cast(DATEDIFF(MONTH,CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END, Expirationdate ) as decimal(7,1))
       --     END AS MembershipLengthmONTHS
       
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs #C 
       ON #C.ClubID = C.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN #MemberTypes #MT 
       ON #MT.MemberType = VMT.Description 
  JOIN dbo.vValMembershipTypeFamilyStatus MTFS
       ON MST.ValMembershipTypeFamilyStatusID = MTFS.ValMembershipTypeFamilyStatusID
  LEFT JOIN dbo.vCompany CO
       ON MS.CompanyID = CO.CompanyID
  LEFT JOIN dbo.vPrimaryPhone PP
       ON MS.MembershipID = PP.MembershipID
  LEFT JOIN dbo.vMembershipPhone MSP
       ON PP.MembershipID = MSP.MembershipID AND
       PP.ValPhoneTypeID = MSP.ValPhoneTypeID
  LEFT JOIN dbo.vValPhoneType VPT
       ON MSP.ValPhoneTypeID = VPT.ValPhoneTypeID
  LEFT JOIN dbo.vMembershipAddress MA
       ON MS.MembershipID = MA.MembershipID
  LEFT JOIN dbo.vValState VS
       ON MA.ValStateID = VS.ValStateID
  LEFT JOIN dbo.vValCountry VC
       ON MA.ValCountryID = VC.ValCountryID
  LEFT JOIN dbo.vValTerminationReason VTR
       ON VTR.ValTerminationReasonID = MS.ValTerminationReasonID 
 WHERE M.ActiveFlag = 1 AND       
       C.DisplayUIFlag = 1 AND       
       VMS.Description = 'Terminated' AND
       MS.ExpirationDate BETWEEN @StartDate AND @EndDate AND
       MST.ShortTermMembershipFlag = 0 AND
       M.LastName NOT IN ('FEES', 'House Account', 'MLTAC')      
       
ELSE

SELECT VR.Description RegionDescription, C.DomainNamePrefix, C.ClubName,
       M.MemberID, M.FirstName, M.LastName, M.JoinDate,
       MS.CreatedDateTime, VPT.Description PhoneTypeDescription, MSP.AreaCode,
       MSP.Number, MS.MembershipID, VMS.Description MembershipStatusDescription,
       P.ProductID, P.Description ProductDescription, M.DOB,
       DATEDIFF ( year, M.DOB, GETDATE() ) Age,
       VMT.Description MemberTypeDescription, MA.AddressLine1, MA.AddressLine2,
       MA.City, VS.Abbreviation StateAbbreviation, MA.Zip,
       VC.Abbreviation CountryAbbreviation, GETDATE() QueryDate, M.Gender,
       VMT.SortOrder MemberTypeSortOrder, MS.CompanyID, CO.CompanyName,
       CO.CorporateCode, MTFS.Description MembershipSizeDescription,
       MS.ExpirationDate, VTR.Description TermReasonDescription,
              CASE WHEN MS.CompanyID IS NULL THEN 0 ELSE 1 END AS CorpAffiliationFlag, 
       CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END AS  MembershipCreateDate,     
       CONVERT(DECIMAL(5,1),          
       CASE WHEN MS.ExpirationDate IS NULL 
            THEN DATEDIFF(MONTH,CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END, GETDATE())  / 12.0
            ELSE DATEDIFF(MONTH,CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END, Expirationdate )/12.0  
            END) AS MembershipLengthYears,
       SUBSTRING(DATENAME(mm,CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END),1,3) AS MembershipCreateDateMonth,
       'Q' + CONVERT(VARCHAR(2),DATEPART(QQ, CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END)) AS MembershipCreateDateQuarter,                 
       DATEPART(YEAR, CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END) AS MembershipCreateDateYear,
       @TerminatedOrNonTerminated AS HeaderMembershipStatus,
       @HeaderMemberTypeList AS HeaderMemberType,
       @ReportRunDateTime AS ReportRunDateTime,
       @HeaderDateRange AS HeaderDateRange
            
       --CASE WHEN MS.ExpirationDate IS NULL 
       --     THEN CASt(DATEDIFF(MONTH,CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END, GETDATE()) AS decimal(7,1))
       --     ELSE cast(DATEDIFF(MONTH,CASE WHEN MS.CreatedDateTime IS NULL THEN M.JoinDate ELSE MS.CreatedDateTime END, Expirationdate ) as decimal(7,1))
       --     END AS MembershipLengthmONTHS

  FROM dbo.vMember M	
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs #C
       ON #C.ClubID = C.ClubID 
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN #MemberTypes #MT 
       ON #MT.MemberType =VMT.Description 
  JOIN dbo.vValMembershipTypeFamilyStatus MTFS
       ON MST.ValMembershipTypeFamilyStatusID = MTFS.ValMembershipTypeFamilyStatusID
  LEFT JOIN dbo.vCompany CO
       ON MS.CompanyID = CO.CompanyID
  LEFT JOIN dbo.vPrimaryPhone PP
       ON MS.MembershipID = PP.MembershipID
  LEFT JOIN dbo.vMembershipPhone MSP
       ON PP.MembershipID = MSP.MembershipID AND
       PP.ValPhoneTypeID = MSP.ValPhoneTypeID
  LEFT JOIN dbo.vValPhoneType VPT
       ON MSP.ValPhoneTypeID = VPT.ValPhoneTypeID
  LEFT JOIN dbo.vMembershipAddress MA
       ON MS.MembershipID = MA.MembershipID
  LEFT JOIN dbo.vValState VS
       ON MA.ValStateID = VS.ValStateID
  LEFT JOIN dbo.vValCountry VC
       ON MA.ValCountryID = VC.ValCountryID
  LEFT JOIN dbo.vValTerminationReason VTR
       ON VTR.ValTerminationReasonID = MS.ValTerminationReasonID 
 WHERE M.ActiveFlag = 1 AND
       VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') AND
       M.JoinDate BETWEEN @StartDate AND @EndDate AND
       C.DisplayUIFlag = 1 AND
       MST.ShortTermMembershipFlag = 0 AND
       M.LastName NOT IN ('FEES', 'House Account', 'MLTAC')      

DROP TABLE #Clubs
DROP TABLE #MemberTypes
DROP TABLE #tmpList

END

