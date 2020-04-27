

CREATE PROC [dbo].[procCognos_CorporateSalesEngagement] (
      @CompanyIDList VARCHAR(MAX)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON


 ----------
 ---- Query initially based on code FROM procCognos_CorporateMenbershipList
 ---- Execution sample:   Exec procCognos_CorporateSalesEngagement '57'
 ----------



DECLARE @FirstOfReportMonth DateTime
DECLARE @FirstOfReportYear DateTime
SET @FirstOfReportMonth = (SELECT CalendarMonthStartingDate FROM vReportDimDate WHERE CalendarDate = convert(datetime,convert(varchar,GetDate(),110),110))
SET @FirstOfReportYear = (SELECT ('01/01/'+Convert(varchar,CalendarYear)) FROM vReportDimDate WHERE CalendarDate = convert(datetime,convert(varchar,GetDate(),110),110))



DECLARE @ReportDate Datetime
SET @ReportDate = GetDate()

DECLARE @ReportRunDateTime VARCHAR(21)
DECLARE @HeaderMembershipStatuses  VARCHAR(100)

SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')
SET @HeaderMembershipStatuses = 'Active, Late Activation, Non-Paid, Non-Paid Late Activation, Pending Termination'

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #CompanyIDList (CompanyID VARCHAR(50))
EXEC procParseStringList @CompanyIDList
INSERT INTO #CompanyIDList (CompanyID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList


SELECT DISTINCT ClubID as ClubID
  INTO #Clubs
  FROM vClub Club



 ---- To limit scans of this table later in the proc.
SELECT CalendarDate,CalendarMonthNumberInYear
 INTO #YTDDates
 FROM vReportDimDate
  WHERE CalendarDate >=@FirstOfReportYear
   AND  CalendarDate < @ReportDate

 --- Gather list of all memberships with selected corporate affiliation - Membership Company or Reimbursement Program Company
 --- within the selected clubs and Membership Types

   ---- returns one record for each member with an active a reimb. program company
SELECT M.MembershipID, MS.MembershipTypeID,MS.CurrentPrice,MS.ValMembershipStatusID,M.MemberID, CO.CompanyID,
convert(datetime,convert(varchar,IsNull(MS.CreatedDateTime,'1/1/1900'),110),110) AS MembershipCreatedDate,
MS.ClubID, M.ValMemberTypeID,MS.AdvisorEmployeeID,   
SubString(FamilyStatus.Description,1,6) AS FamilyStatus
INTO #CompanyMembers
FROM vMember M
JOIN vMemberReimbursement MR
  ON M.MemberID = MR.MemberID
JOIN vReimbursementProgram RP
  ON MR.ReimbursementProgramID = RP.ReimbursementProgramID
JOIN vCompany CO
  ON RP.CompanyID = CO.CompanyID
JOIN vMembership MS
  ON M.MembershipID = MS.MembershipID
JOIN vValMembershipStatus VMS
  ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
JOIN #Clubs #Clubs
  ON MS.ClubID = #Clubs.ClubID
JOIN #CompanyIDList #C
  ON (Convert(varchar,CO.CompanyID) = Convert(Varchar,#C.CompanyID)
    OR #C.CompanyID = '0')
JOIN vMembershipType MT
  ON MS.MembershipTypeID = MT.MembershipTypeID
JOIN vValMembershipTypeFamilyStatus as FamilyStatus
  ON MT.ValMembershipTypeFamilyStatusID = FamilyStatus.ValMembershipTypeFamilyStatusID

WHERE MR.EnrollmentDate <= @ReportDate 
  AND ISNull(MR.TerminationDate,'1/1/2100') > @ReportDate   
  AND ISNull(MS.ExpirationDate,'1/1/2100')> @ReportDate 
  AND M.ActiveFlag = 1
  AND VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination')



UNION    

  ------ returns primary member for all memberships which have a membership company affiliation
  SELECT MS.MembershipID,MS.MembershipTypeID,MS.CurrentPrice,MS.ValMembershipStatusID,M.MemberID, CO.CompanyID,
  convert(datetime,convert(varchar,IsNull(MS.CreatedDateTime,'1/1/1900'),110),110) AS MembershipCreatedDate,
  MS.ClubID,M.ValMemberTypeID,MS.AdvisorEmployeeID,SubString(FamilyStatus.Description,1,6) AS FamilyStatus
  FROM vMember M
  JOIN vMembership MS WITH (NOLOCK)
    ON M.MembershipID = MS.MembershipID
  JOIN vValMembershipStatus VMS
    ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN vCompany CO
    ON MS.CompanyID = CO.CompanyID
  JOIN #Clubs #Clubs
    ON MS.ClubID = #Clubs.ClubID
  JOIN #CompanyIDList #C
    ON (Convert(varchar,CO.CompanyID) = Convert(Varchar,#C.CompanyID)
    OR #C.CompanyID = '0')
  JOIN vMembershipType MT
    ON MS.MembershipTypeID = MT.MembershipTypeID
JOIN vValMembershipTypeFamilyStatus as FamilyStatus
  ON MT.ValMembershipTypeFamilyStatusID = FamilyStatus.ValMembershipTypeFamilyStatusID
 WHERE VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination')
   AND M.ValMemberTypeID = 1
   AND M.ActiveFlag = 1

   -- Rank is assigned based on ValMemberType order for each Membership to enable selecting just 1 record per membership		
SELECT MembershipID,
       MembershipTypeID,
	   CurrentPrice,
	   ValMembershipStatusID,
       MemberID, 
	   CompanyID,
	   ClubID,
	   ValMemberTypeID,	
	   AdvisorEmployeeID,
	   MembershipCreatedDate,
	   FamilyStatus,
       RANK() OVER (PARTITION BY MembershipID				
                        ORDER BY ValMemberTypeID,MemberID) MembershipMemberRank				
  INTO #CompanyMembershipsRanked				
  FROM #CompanyMembers	



-----  find Club IDs for company memberships
SELECT ClubID
 INTO #CompanyMembershipClubs
FROM #CompanyMembershipsRanked
 GROUP BY ClubID

-- total tax percentage for a given product and club 
CREATE TABLE #ClubProductTaxRate (
	ClubID INT, 
	ProductID INT,
	ValTaxTypeID INT, 
	TaxPercentage SMALLMONEY 
	)

INSERT INTO #ClubProductTaxRate 
	SELECT CPTR.ClubID, 
	       CPTR.ProductID,
		   TR.ValTaxTypeID, 
		   Sum(TR.TaxPercentage) AS TaxPercentage 
	FROM vClubProductTaxRate CPTR
	JOIN vTaxRate TR 
	 ON TR.TaxRateID = CPTR.TaxRateID
	JOIN #CompanyMembershipClubs #Clubs
	 ON  CPTR.ClubID = #Clubs.ClubID
	GROUP BY CPTR.ClubID, CPTR.ProductID,TR.ValTaxTypeID


---- calculate Membership Junior dues rate
SELECT MPT.MembershipID,
       PT.ProductID, 
	   C.ClubID,
       SUM(PTP.Price)  AS MembershipJrDues
INTO #MembershipJuniorDues           
FROM vMembershipProductTier  MPT
 JOIN vProductTier PT
   ON MPT.ProductTierID = PT.ProductTierID
 JOIN #CompanyMembershipsRanked MS
   ON MPT.MembershipID = MS.MembershipID
 JOIN vClub C
   ON MS.ClubID = C.ClubID
 JOIN vMembershipType MT
   ON MS.MembershipTypeID = MT.MembershipTypeID
 JOIN vProductTierPrice PTP
   ON PT.ProductTierID = PTP.ProductTierID
 JOIN vValMembershipTypeGroup VMTG
   ON PTP.ValMembershipTypeGroupID = VMTG.ValMembershipTypeGroupID
   AND MT.ValMembershipTypeGroupID = VMTG.ValMembershipTypeGroupID
 JOIN vMember M
   ON M.MembershipID = MS.MembershipID
 WHERE M.ValMemberTypeID = 4
       AND M.ActiveFlag = 1
       AND PT.ValProductTierTypeID = 1 ---- Fun Play dues
       AND (M.AssessJrMemberDuesFlag = 1 or M.AssessJrMemberDuesFlag is null )
       AND (C.AssessJrMemberDuesFlag = 1 or C.AssessJrMemberDuesFlag is null )
       AND (MT.AssessJrMemberDuesFlag = 1 or MT.AssessJrMemberDuesFlag is null )
	   AND MS.MembershipMemberRank = 1
 GROUP BY MPT.MembershipID,PT.ProductID, C.ClubID
 ORDER BY MPT.MembershipID

  --- Temp table created to reduce large table MMSTran joined to another large table TranItem in later query
 Select MS.MembershipID,MMSTran.MMSTranID,#YTDDates.CalendarMonthNumberInYear
   INTO #YTDMembershipTransactions
  From #CompanyMembershipsRanked MS
     JOIN vMMSTran MMSTran
	   ON MS.MembershipID = MMSTran.MembershipID
	 JOIN #YTDDates
	   ON convert(datetime,convert(varchar,MMSTran.PostDateTime,110),110) = #YTDDates.CalendarDate
   WHERE MS.MembershipMemberRank = 1
	 AND MMSTran.PostDateTime >= @FirstOfReportYear
	 AND IsNull(MMSTran.TranVoidedID,0) = 0

  ------ Gather membership dues for the year
  SELECT MMSTran.MembershipID,
    SUM(CASE WHEN MMSTran.CalendarMonthNumberInYear = 1
	     THEN TranItem.ItemAmount
		 ELSE 0
		 END) JanuaryDues,
    SUM(CASE WHEN MMSTran.CalendarMonthNumberInYear = 2
	     THEN TranItem.ItemAmount
		 ELSE 0
		 END) FebruaryDues,
    SUM(CASE WHEN MMSTran.CalendarMonthNumberInYear = 3
	     THEN TranItem.ItemAmount
		 ELSE 0
		 END) MarchDues,
    SUM(CASE WHEN MMSTran.CalendarMonthNumberInYear = 4
	     THEN TranItem.ItemAmount
		 ELSE 0
		 END) AprilDues,
    SUM(CASE WHEN MMSTran.CalendarMonthNumberInYear = 5
	     THEN TranItem.ItemAmount
		 ELSE 0
		 END) MayDues,
    SUM(CASE WHEN MMSTran.CalendarMonthNumberInYear = 6
	     THEN TranItem.ItemAmount
		 ELSE 0
		 END) JuneDues,
    SUM(CASE WHEN MMSTran.CalendarMonthNumberInYear = 7
	     THEN TranItem.ItemAmount
		 ELSE 0
		 END) JulyDues,
    SUM(CASE WHEN MMSTran.CalendarMonthNumberInYear = 8
	     THEN TranItem.ItemAmount
		 ELSE 0
		 END) AugustDues,
    SUM(CASE WHEN MMSTran.CalendarMonthNumberInYear = 9
	     THEN TranItem.ItemAmount
		 ELSE 0
		 END) SeptemberDues,
    SUM(CASE WHEN MMSTran.CalendarMonthNumberInYear = 10
	     THEN TranItem.ItemAmount
		 ELSE 0
		 END) OctoberDues,
    SUM(CASE WHEN MMSTran.CalendarMonthNumberInYear = 11
	     THEN TranItem.ItemAmount
		 ELSE 0
		 END) NovemberDues,
    SUM(CASE WHEN MMSTran.CalendarMonthNumberInYear = 12
	     THEN TranItem.ItemAmount
		 ELSE 0
		 END) DecemberDues
   INTO #YTDMembershipDues
   FROM #YTDMembershipTransactions MMSTran
     JOIN vTranItem TranItem
	   ON MMSTran.MMSTranID = TranItem.MMSTranID
	 JOIN vProduct Product
	   ON TranItem.ProductID = Product.ProductID
   WHERE Product.DepartmentID = 1
	 AND IsNull(Product.AssessAsDuesFlag,1) = 1
   GROUP BY MMSTran.MembershipID


SELECT Count(MS.MembershipID) AS TotalMemberships,
       -----C.ClubName,
       CO.CompanyName,
	   CO.CorporateCode,
	   CO.CompanyID,
	   CO.AccountOwner,
	   CO.NumberOfEmployees,
	   CO.TotalEligibleEmployees,
	   SUM(IsNull(MS.CurrentPrice,0)) AS MembershipDues,
	   SUM(ISNull(#MJD.MembershipJrDues,0)) AS MembershipJrDues,
	   SUM(CASE WHEN CPTR.TaxPercentage IS NULL THEN 0  
	      ELSE IsNull(MS.CurrentPrice,0) * (CPTR.TaxPercentage * .01) 
		  END) TaxOnMembershipDues,
	   SUM(CASE WHEN #CPTR_JM.TaxPercentage IS NULL THEN 0
          ELSE ISNull(#MJD.MembershipJrDues,0) * (#CPTR_JM.TaxPercentage * .01)
          END) TaxOnJuniorDues,
	 @HeaderMembershipStatuses AS HeaderMembershipStatuses,
	 @ReportRunDateTime AS ReportRunDateTime,
	 'Local Currency' AS ReportingCurrencyCode,
	 SUM(CASE WHEN MS.FamilyStatus  = 'Single'
	      THEN 1
		  ELSE 0
		  END) SingleMembershipCount,
     SUM(CASE WHEN MS.FamilyStatus = 'Couple'
	      THEN 1
		  ELSE 0
		  END) CoupleMembershipCount,
     SUM(CASE WHEN MS.FamilyStatus  = 'Family'
	      THEN 1
		  ELSE 0
		  END) FamilyMembershipCount,
	 MAX(CASE WHEN IsNull(CO.ActiveAccountFlag,0)=1
	      THEN 'Active'
		  ELSE 'Inactive'
		  END) AS CompanyActiveStatus,
	 SUM(CASE WHEN IsNull(MembershipCreatedDate,'1/1/1900') >= @FirstOfReportMonth 
	      THEN 1
		  ELSE 0
		  END) MTDMembershipCount,
     SUM(CASE WHEN IsNull(MembershipCreatedDate,'1/1/1900') >= @FirstOfReportYear
	        AND  IsNull(MembershipCreatedDate,'1/1/1900') < DATEADD(month,1,@FirstOfReportYear)
	      THEN 1
		  ELSE 0
		  END) JanuaryMembershipCount,
	 SUM(CASE WHEN IsNull(MembershipCreatedDate,'1/1/1900') >= DATEADD(month,1,@FirstOfReportYear)
	        AND  IsNull(MembershipCreatedDate,'1/1/1900') < DATEADD(month,2,@FirstOfReportYear)
	      THEN 1
		  ELSE 0
		  END) FebruaryMembershipCount,
	 SUM(CASE WHEN IsNull(MembershipCreatedDate,'1/1/1900') >= DATEADD(month,2,@FirstOfReportYear)
	        AND  IsNull(MembershipCreatedDate,'1/1/1900') < DATEADD(month,3,@FirstOfReportYear)
	      THEN 1
		  ELSE 0
		  END) MarchMembershipCount,
	 SUM(CASE WHEN IsNull(MembershipCreatedDate,'1/1/1900') >= DATEADD(month,3,@FirstOfReportYear)
	        AND  IsNull(MembershipCreatedDate,'1/1/1900') < DATEADD(month,4,@FirstOfReportYear)
	      THEN 1
		  ELSE 0
		  END) AprilMembershipCount,	
	 SUM(CASE WHEN IsNull(MembershipCreatedDate,'1/1/1900') >= DATEADD(month,4,@FirstOfReportYear)
	        AND  IsNull(MembershipCreatedDate,'1/1/1900') < DATEADD(month,5,@FirstOfReportYear)
	      THEN 1
		  ELSE 0
		  END) MayMembershipCount,
	 SUM(CASE WHEN IsNull(MembershipCreatedDate,'1/1/1900') >= DATEADD(month,5,@FirstOfReportYear)
	        AND  IsNull(MembershipCreatedDate,'1/1/1900') < DATEADD(month,6,@FirstOfReportYear)
	      THEN 1
		  ELSE 0
		  END) JuneMembershipCount,
	 SUM(CASE WHEN IsNull(MembershipCreatedDate,'1/1/1900') >= DATEADD(month,6,@FirstOfReportYear)
	        AND  IsNull(MembershipCreatedDate,'1/1/1900') < DATEADD(month,7,@FirstOfReportYear)
	      THEN 1
		  ELSE 0
		  END) JulyMembershipCount,
	 SUM(CASE WHEN IsNull(MembershipCreatedDate,'1/1/1900') >= DATEADD(month,7,@FirstOfReportYear)
	        AND  IsNull(MembershipCreatedDate,'1/1/1900') < DATEADD(month,8,@FirstOfReportYear)
	      THEN 1
		  ELSE 0
		  END) AugustMembershipCount,
	 SUM(CASE WHEN IsNull(MembershipCreatedDate,'1/1/1900') >= DATEADD(month,8,@FirstOfReportYear)
	        AND  IsNull(MembershipCreatedDate,'1/1/1900') < DATEADD(month,9,@FirstOfReportYear)
	      THEN 1
		  ELSE 0
		  END) SeptemberMembershipCount,
	 SUM(CASE WHEN IsNull(MembershipCreatedDate,'1/1/1900') >= DATEADD(month,9,@FirstOfReportYear)
	        AND  IsNull(MembershipCreatedDate,'1/1/1900') < DATEADD(month,10,@FirstOfReportYear)
	      THEN 1
		  ELSE 0
		  END) OctoberMembershipCount,
	 SUM(CASE WHEN IsNull(MembershipCreatedDate,'1/1/1900') >= DATEADD(month,10,@FirstOfReportYear)
	        AND  IsNull(MembershipCreatedDate,'1/1/1900') < DATEADD(month,11,@FirstOfReportYear)
	      THEN 1
		  ELSE 0
		  END) NovemberMembershipCount,	
	 SUM(CASE WHEN IsNull(MembershipCreatedDate,'1/1/1900') >= DATEADD(month,11,@FirstOfReportYear)
	        AND  IsNull(MembershipCreatedDate,'1/1/1900') < DATEADD(month,12,@FirstOfReportYear)
	      THEN 1
		  ELSE 0
		  END) DecemberMembershipCount,
	 SUM(YTDMD.JanuaryDues) AS JanuaryDues,
	 SUM(YTDMD.FebruaryDues) AS FebruaryDues,
	 SUM(YTDMD.MarchDues) AS MarchDues,
	 SUM(YTDMD.AprilDues) AS AprilDues,
	 SUM(YTDMD.MayDues) AS MayDues,
	 SUM(YTDMD.JuneDues) AS JuneDues,
	 SUM(YTDMD.JulyDues) AS JulyDues,
	 SUM(YTDMD.AugustDues) AS AugustDues,
	 SUM(YTDMD.SeptemberDues) AS SeptemberDues,
	 SUM(YTDMD.OctoberDues) AS OctoberDues,
	 SUM(YTDMD.NovemberDues) AS NovemberDues,
	 SUM(YTDMD.DecemberDues) AS DecemberDues 	 	 	 	 	 	  
  FROM #CompanyMembershipsRanked MS
  JOIN vClub C
    ON MS.ClubID=C.ClubID
  JOIN #YTDMembershipDues YTDMD
    ON MS.MembershipID = YTDMD.MembershipID
  JOIN vCompany CO
    ON MS.CompanyID=CO.CompanyID
  JOIN vMembershipType MT
    ON MS.MembershipTypeID=MT.MembershipTypeID
  JOIN vProduct P
    ON P.ProductID=MT.ProductID 
  LEFT JOIN #ClubProductTaxRate CPTR
    ON CPTR.ProductID = P.ProductID
   AND CPTR.ClubID = MS.ClubID
  LEFT JOIN vValTaxType VTT
    ON CPTR.ValTaxTypeID = VTT.ValTaxTypeID
  LEFT JOIN #MembershipJuniorDues #MJD
       ON MS.MembershipID = #MJD.MembershipID
  LEFT JOIN #ClubProductTaxRate #CPTR_JM 
	   ON #CPTR_JM.ClubID = #MJD.ClubID 
	   AND #CPTR_JM.ProductID = #MJD.ProductID 
  WHERE MS.MembershipMemberRank = 1
  GROUP BY 	   CO.CompanyName,
	   CO.CorporateCode,
	   CO.CompanyID,
	   CO.AccountOwner,
	   CO.NumberOfEmployees,
	   CO.TotalEligibleEmployees  
	   ------,C.ClubName




DROP TABLE #tmpList
DROP TABLE #YTDDates
DROP TABLE #CompanyIDList
DROP TABLE #Clubs
DROP TABLE #CompanyMembers
DROP TABLE #CompanyMembershipsRanked
DROP TABLE #ClubProductTaxRate
DROP TABLE #CompanyMembershipClubs
DROP TABLE #MembershipJuniorDues
DROP TABLE #YTDMembershipDues
DROP TABLE #YTDMembershipTransactions

END

