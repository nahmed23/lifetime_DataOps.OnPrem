



CREATE  PROC [dbo].[procCognos_RecurrentProductAudit_Obsolete] (
  @StartDate DATETIME,
  @EndDate DATETIME,
  @ClubIDList VARCHAR(1000),
  @DepartmentMinDimReportingHierarchyKeyList VARCHAR(8000)
)
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON


IF 1=0 BEGIN
       SET FMTONLY OFF
     END

----- Sample Execution
---	Exec procCognos_RecurrentProductAudit '1/1/2017', '1/30/2017', '151|8', '101|120|123|142|212|213|214|220|225'
-----


SET @EndDate = DATEADD(DAY,1,@EndDate) -- to include all end date transactions due to stored time


DECLARE @HeaderDateRange VARCHAR(33) 
DECLARE @ReportRunDateTime VARCHAR(21) 

SET @HeaderDateRange = convert(varchar(12), @StartDate, 107) + ' to ' + convert(varchar(12), @EndDate, 107)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')



  CREATE TABLE #tmpList (StringField VARCHAR(50))
  
  -- Parse the ClubIDs into a temp table  
CREATE TABLE #Clubs (ClubID VARCHAR(50))
IF @ClubIDList like '%All Clubs%'
  BEGIN
  INSERT INTO #Clubs (ClubID) SELECT ClubID FROM vClub
 END
 ELSE
 BEGIN 
  EXEC procParseIntegerList @ClubIDList
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
 END



  
  ----- Return the hierarchy keys for the selected departments
SELECT ReportDimReportingHierarchy.DimReportingHierarchyKey,
       ReportDimReportingHierarchy.DivisionName,
       ReportDimReportingHierarchy.SubdivisionName,
       ReportDimReportingHierarchy.DepartmentName,
       ReportDimReportingHierarchy.ProductGroupName,
       ReportDimReportingHierarchy.ProductGroupSortOrder,
       ReportDimReportingHierarchy.RegionType
  INTO #DimReportingHierarchy
  FROM vReportDimReportingHierarchy BridgeTable
  JOIN fnParsePipeList(@DepartmentMinDimReportingHierarchyKeyList) KeyList
    ON BridgeTable.DimReportingHierarchyKey = KeyList.Item
  JOIN vReportDimReportingHierarchy ReportDimReportingHierarchy
    ON BridgeTable.DivisionName = ReportDimReportingHierarchy.DivisionName
   AND BridgeTable.SubdivisionName = ReportDimReportingHierarchy.SubdivisionName
   AND BridgeTable.DepartmentName = ReportDimReportingHierarchy.DepartmentName





  ----- to find all recurrent product members within selection parameters
 SELECT MRP.MemberID
 INTO #RecurrentProductMembers
 FROM vMembershipRecurrentProduct MRP
 JOIN #Clubs  
   ON MRP.ClubID = #Clubs.ClubID
 JOIN vReportDimProduct Product
   ON MRP.ProductID = Product.MMSProductID
 JOIN #DimReportingHierarchy 
   ON Product.DimReportingHierarchyKey = #DimReportingHierarchy.DimReportingHierarchyKey
 WHERE MRP.CreatedDateTime >= @StartDate 
   AND MRP.CreatedDateTime <= @EndDate
 GROUP BY MRP.MemberID




 ---- to find all Corporate Partners for these recurrent product members
 SELECT MemberReimbursement.MemberID,
        MemberReimbursement.ReimbursementProgramID,
		CorporatePartner.PartnerName,
		MemberReimbursement.EnrollmentDate,
		MemberReimbursement.TerminationDate,
		RANK() OVER (PARTITION BY MemberReimbursement.MemberID
                        ORDER BY CorporatePartner.PartnerName) CorporatePartnerRanking
  INTO #RankedMemberCorporatePartner
 FROM vMemberReimbursement MemberReimbursement
   JOIN #RecurrentProductMembers ReportMembers
     ON MemberReimbursement.MemberID = ReportMembers.MemberID
   JOIN vCorporatePartnerProgram PartnerProgram
     ON MemberReimbursement.ReimbursementProgramID = PartnerProgram.ReimbursementProgramID
   JOIN vCorporatePartner  CorporatePartner
     ON PartnerProgram.CorporatePartnerID = CorporatePartner.CorporatePartnerID
 WHERE MemberReimbursement.EnrollmentDate < @EndDate
  AND IsNull(MemberReimbursement.TerminationDate,@EndDate) >= @EndDate
  AND PartnerProgram.EffectiveFromDateTime < @EndDate
  AND IsNull(PartnerProgram.EffectiveThruDateTime,@EndDate) >= @EndDate

  UNION ALL

SELECT Member.MemberID,
       0 AS ReimbursementProgramID,
	   Company.CompanyName AS PartnerName,
	   Membership.CreatedDateTime AS EnrollmentDate,
	   Membership.ExpirationDate AS TerminationDate,
	   5 AS CorporatePartnerRanking
FROM vMembership Membership
 JOIN vCompany Company
   ON Membership.CompanyID = Company.CompanyID
 JOIN vMember Member
   ON Membership.MembershipID = Member.MembershipID
 JOIN #RecurrentProductMembers ReportMembers
     ON Member.MemberID = ReportMembers.MemberID

 



 --- return 1 line per member for up to 5 Corporate Partners
SELECT MemberID,
       MAX(CASE WHEN #RankedMemberCorporatePartner.CorporatePartnerRanking = 1
	        THEN PartnerName
			ELSE ''
			END) 'CorporatePartner1',
       MAX(CASE WHEN #RankedMemberCorporatePartner.CorporatePartnerRanking = 2
	        THEN ', ' + PartnerName
			ELSE ''
			END) 'CorporatePartner2',
	   MAX(CASE WHEN #RankedMemberCorporatePartner.CorporatePartnerRanking = 3
	        THEN ', ' + PartnerName
			ELSE ''
			END) 'CorporatePartner3',
	   MAX(CASE WHEN #RankedMemberCorporatePartner.CorporatePartnerRanking = 4
	        THEN ', ' + PartnerName
			ELSE ''
			END) 'CorporatePartner4',
	   MAX(CASE WHEN #RankedMemberCorporatePartner.CorporatePartnerRanking = 5
	        THEN PartnerName
			ELSE ''
			END) 'CorporatePartner5'
 INTO #MemberCorporatePartners
FROM #RankedMemberCorporatePartner
GROUP BY MemberID






 ---- Return reporting detail
SELECT 
	C.ClubName, 
	Hier.DepartmentName DeptDescription, 
	MRP.MembershipRecurrentProductID, 
	MRP.CreatedDateTime as CreatedDateTime_Sort, 
	Replace(SubString(Convert(Varchar, MRP.CreatedDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.CreatedDateTime),5,DataLength(Convert(Varchar, MRP.CreatedDateTime))-12)),' '+Convert(Varchar,Year(MRP.CreatedDateTime)),', '+Convert(Varchar,Year(MRP.CreatedDateTime))) AS CreatedDateTime,
	P.ProductDescription ProductDesc, 	
	CASE 	
		WHEN IsNull(PkgMbr.MemberID,0) = 0 
		  THEN  PrimaryMbr.FirstName + ' ' + PrimaryMbr.LastName
		ELSE PkgMbr.FirstName + ' ' + PkgMbr.LastName
	    END MemberName,
	CASE 	
		WHEN IsNull(PkgMbr.MemberID,0) = 0 
		  THEN  PrimaryMbr.LastName
		ELSE PkgMbr.LastName
	    END MemberLastName,
	CASE 	
		WHEN IsNull(PkgMbr.MemberID,0) = 0  
		  THEN  PrimaryMbr.FirstName
		ELSE PkgMbr.FirstName
	    END MemberFirstName,
	CASE 	
		WHEN IsNull(PkgMbr.MemberID,0) = 0  
		  THEN  PrimaryMbr.MemberID
		ELSE PkgMbr.MemberID
	    END MemberID,
	MRP.MembershipID, 
	MRP.ActivationDate, 
	Replace(SubString(Convert(Varchar, MRP.ActivationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.ActivationDate),5,DataLength(Convert(Varchar, MRP.ActivationDate))-12)),' '+Convert(Varchar,Year(MRP.ActivationDate)),', '+Convert(Varchar,Year(MRP.ActivationDate))) AS ActivationDate_Formatted,
	MRP.TerminationDate, 
	Replace(SubString(Convert(Varchar, MRP.TerminationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.TerminationDate),5,DataLength(Convert(Varchar, MRP.TerminationDate))-12)),' '+Convert(Varchar,Year(MRP.TerminationDate)),', '+Convert(Varchar,Year(MRP.TerminationDate))) AS TerminationDate_Formatted,
	MRP.ProductHoldBeginDate,
	Replace(SubString(Convert(Varchar, MRP.ProductHoldBeginDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.ProductHoldBeginDate),5,DataLength(Convert(Varchar, MRP.ProductHoldBeginDate))-12)),' '+Convert(Varchar,Year(MRP.ProductHoldBeginDate)),', '+Convert(Varchar,Year(MRP.ProductHoldBeginDate))) AS ProductHoldBeginDate_Formatted,
	MRP.ProductHoldEndDate,
	Replace(SubString(Convert(Varchar, MRP.ProductHoldEndDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.ProductHoldEndDate),5,DataLength(Convert(Varchar, MRP.ProductHoldEndDate))-12)),' '+Convert(Varchar,Year(MRP.ProductHoldEndDate)),', '+Convert(Varchar,Year(MRP.ProductHoldEndDate))) AS ProductHoldEndDate_Formatted,
	E.FirstName, 
	E.LastName,
	COALESCE(E.FirstName, '') + ' ' + COALESCE(E.LastName, '') Commission,
	MRP.NumberOfSessions, 
	MRP.PricePerSession  AS PricePerSession,	  
    MRP.Price  AS Price,	
    'Local Currency' AS ReportingCurrencyCode,
	@HeaderDateRange AS HeaderDateRange,
	@ReportRunDateTime AS ReportRunDateTime,
	Membership.CurrentPrice AS MembershipDuesAmount,
	CASE WHEN IsNull(PkgMbr.MemberID,0) = 0 
		  THEN  CASE WHEN PrimaryMbrCorporatePartners.CorporatePartner1 = ''
		             THEN PrimaryMbrCorporatePartners.CorporatePartner5
					 WHEN PrimaryMbrCorporatePartners.CorporatePartner5 = ''
					 THEN PrimaryMbrCorporatePartners.CorporatePartner1 + PrimaryMbrCorporatePartners.CorporatePartner2 + PrimaryMbrCorporatePartners.CorporatePartner3 + PrimaryMbrCorporatePartners.CorporatePartner4
					 ELSE PrimaryMbrCorporatePartners.CorporatePartner5 + ', '+ PrimaryMbrCorporatePartners.CorporatePartner1 + PrimaryMbrCorporatePartners.CorporatePartner2 + PrimaryMbrCorporatePartners.CorporatePartner3 + PrimaryMbrCorporatePartners.CorporatePartner4
		             END
		 ELSE CASE WHEN PkgMbrCorporatePartners.CorporatePartner1 = ''
		             THEN PkgMbrCorporatePartners.CorporatePartner5
					 WHEN PkgMbrCorporatePartners.CorporatePartner5 = ''
					 THEN PkgMbrCorporatePartners.CorporatePartner1 + PkgMbrCorporatePartners.CorporatePartner2 + PkgMbrCorporatePartners.CorporatePartner3 + PkgMbrCorporatePartners.CorporatePartner4
					 ELSE PkgMbrCorporatePartners.CorporatePartner5 + ', '+ PkgMbrCorporatePartners.CorporatePartner1 + PkgMbrCorporatePartners.CorporatePartner2 + PkgMbrCorporatePartners.CorporatePartner3 + PkgMbrCorporatePartners.CorporatePartner4
                     END
	 END MemberCorporatePartners
 
FROM vMembershipRecurrentProduct MRP
 JOIN vClub C 
   ON MRP.ClubID=C.ClubID
 JOIN #Clubs #C 
   ON C.ClubID = #C.ClubID
 LEFT JOIN vMember PkgMbr 
   ON MRP.MemberID=PkgMbr.MemberID
 LEFT JOIN  #MemberCorporatePartners PkgMbrCorporatePartners
   ON PkgMbr.MemberID = PkgMbrCorporatePartners.MemberID
 JOIN vMember PrimaryMbr 
   ON MRP.MembershipID=PrimaryMbr.MembershipID
 LEFT JOIN  #MemberCorporatePartners PrimaryMbrCorporatePartners
   ON PrimaryMbr.MemberID = PrimaryMbrCorporatePartners.MemberID
 LEFT JOIN vEmployee E 
   ON  MRP.CommissionEmployeeID=E.EmployeeID
 JOIN vReportDimProduct P 
   ON  MRP.ProductID=P.MMSProductID
 JOIN #DimReportingHierarchy Hier 
   ON P.DimReportingHierarchyKey = Hier.DimReportingHierarchyKey
 JOIN vMembership Membership
   ON MRP.MembershipID = Membership.MembershipID
   
WHERE PrimaryMbr.ValMemberTypeID = 1 
  AND MRP.CreatedDateTime >= @StartDate 
  AND MRP.CreatedDateTime <= @EndDate





  DROP TABLE #tmpList
  DROP TABLE #Clubs
  DROP TABLE #DimReportingHierarchy
  DROP TABLE #RecurrentProductMembers
  DROP TABLE #RankedMemberCorporatePartner
  DROP TABLE #MemberCorporatePartners



END


