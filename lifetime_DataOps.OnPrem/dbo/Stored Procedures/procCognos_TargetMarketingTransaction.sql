






CREATE    PROC [dbo].[procCognos_TargetMarketingTransaction] (
  @ClubIDList VARCHAR(8000),
  @ProductIDList VARCHAR(8000),
  @StartDate DATETIME,
  @EndDate DATETIME,
  @myLTBucksFilter VARCHAR(50),
  @IncludePriorPurchaseInfoFlag  VARCHAR(5)	
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-------
---- returns transaction and membership details for the Target market 
---- Exec procCognos_TargetMarketingTransaction '151|8','7769|11960|11961|11962|11963|11964','7/1/2016','8/15/2016','Not Limited by myLT Buck$','Y'
-------

DECLARE @HeaderDateRange VARCHAR(33), @ReportRunDateTime VARCHAR(21) 
SET @HeaderDateRange = convert(varchar(12), @StartDate, 107) + ' to ' + convert(varchar(12), @EndDate, 107)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')


  CREATE TABLE #tmpList (StringField VARCHAR(80))
  CREATE TABLE #Clubs (ClubID VARCHAR(50))
  IF @ClubIDList <> 'All Clubs'
    BEGIN
      EXEC procParseStringList @ClubIDList
      INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
      TRUNCATE TABLE #tmpList
    END
  ELSE
    BEGIN
      INSERT INTO #Clubs (ClubID) SELECT ClubID FROM dbo.vClub
    END

CREATE TABLE #Products (ProductID INT)
  EXEC procParseIntegerList @ProductIDList
  INSERT INTO #Products (ProductID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
    
/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@StartDate)
  AND PlanYear <= Year(@EndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@StartDate)
  AND PlanYear <= Year(@EndDate)
  AND ToCurrencyCode = 'USD'
/***************************************/

SET @EndDate = DATEADD(DAY,1,@EndDate)

SELECT SC.TranItemID, MIN(SC.SaleCommissionID) AS SaleCommissionID
  INTO #SaleCommission
  FROM vTranItem TI
  JOIN vMMSTran MMST
       ON TI.MMSTranID = MMST.MMSTranID
  JOIN vSaleCommission SC
       ON TI.TranItemID = SC.TranItemID
 WHERE MMST.PostDateTime BETWEEN @StartDate AND @EndDate 
       AND MMST.TranVoidedID IS NULL         
  GROUP BY SC.TranItemID


----- These 2 queries are used to gather prior purchase data and are only populated if the user has selected that prompt option

  Select MMST.MemberID
  INTO #PurchasingMembersInPeriod
  From #Products #P
     JOIN  vTranItem TI
	   ON TI.ProductID = #P.ProductID
     JOIN vMMSTran MMST
       ON TI.MMSTranID = MMST.MMSTranID 
	 JOIN #Clubs
	   ON MMST.ClubID = #Clubs.ClubID
   WHERE @IncludePriorPurchaseInfoFlag = 'Y' 
       AND MMST.PostDateTime BETWEEN @StartDate AND @EndDate 
       AND MMST.TranVoidedID IS NULL
	   Group By MMST.MemberID 

  SELECT #Members.MemberID,#P.ProductID,Max(MMST.PostDateTime) MostRecentPriorPurchaseDate
     INTO #PriorPurchaseData
   FROM  #PurchasingMembersInPeriod #Members
     JOIN vMMSTran MMST
	   ON #Members.MemberID = MMST.MemberID  
	 JOIN vTranItem TI
       ON TI.MMSTranID = MMST.MMSTranID 
	 JOIN #Products #P
	   ON TI.ProductID = #P.ProductID
	 WHERE @IncludePriorPurchaseInfoFlag = 'Y' 
       AND MMST.PostDateTime < @StartDate 
	   AND MMST.PostDateTime >= '12/1/2012'   --- Look back date based on change request for look back data (REP-2465)
       AND MMST.TranVoidedID IS NULL
	   Group By #Members.MemberID,#P.ProductID



SELECT 
       C.ClubName, M.MemberID, M.FirstName, M.LastName,	   
       TI.Quantity, MMST.PostDateTime as PostDateTime_Sort,
	   Replace(SubString(Convert(Varchar, MMST.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.PostDateTime),5,DataLength(Convert(Varchar, MMST.PostDateTime))-12)),' '+Convert(Varchar,Year(MMST.PostDateTime)),', '+Convert(Varchar,Year(MMST.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.PostDateTime,22),10,5) + ' ' + Right(Convert(Varchar, MMST.PostDateTime ,22),2)) as PostDateTime,    
       MMST.TranDate, P.Description ProductDescription, TI.TranItemID,
       M.MembershipID, VMT.Description MemberTypeDescription,
       MA.Addressline1 MembershipAddressLine1, MA.Addressline2 MembershipAddressLine2, MA.City, MA.Zip,
       VS.Abbreviation StateAbbreviation, VC.Abbreviation CountryAbbreviation,
       M.EmailAddress MemberEmailAddress, MPN.HomePhoneNumber MembershipHomePhoneNumber,
       MPN.BusinessPhoneNumber MembershipBusinessPhoneNumber, 
       D.Description DepartmentDescription,
       VMS.Description MembershipStatusDescription,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Mail' THEN 1 ELSE NULL END) DoNotMailFlag,
       SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Phone' THEN 1 ELSE NULL END) DoNotPhoneFlag,
       --SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via E-Mail' THEN 1 ELSE NULL END) DoNotEmailFlag,
       SUM(CASE WHEN ISNULL(VCPS.Description,'Subscribed') <> 'Subscribed' THEN 1 ELSE NULL END) DoNotEmailFlag,
       POSEmployee.EmployeeID AS POSEmployeeID, POSEmployee.FirstName AS POSFirstName, POSEmployee.LastName AS POSLastName,
       CommissionEmployee.EmployeeID AS CommissionEmployeeEmployeeID, CommissionEmployee.FirstName AS CommissionEmployeeFirstName, CommissionEmployee.LastName AS CommissionEmployeeLastName,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   TI.ItemAmount * #PlanRate.PlanRate as ItemAmount,	  
	   TI.ItemAmount as LocalCurrency_ItemAmount,	  
	   TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount,
/***************************************/
       M.DOB MemberBirthDate,
       M.Gender MemberGender,
       EmployeeMember.EmployeeID EmployeeMember_EmployeeID,
       
       @HeaderDateRange AS HeaderDateRange,
       @ReportRunDateTime AS ReportRunDateTime,
       @myLTBucksFilter as HeaderMyLTBucks,
	   CASE WHEN @IncludePriorPurchaseInfoFlag = 'N'
	        THEN ' '
            WHEN @IncludePriorPurchaseInfoFlag = 'Y'	
			THEN CASE WHEN IsNull(#PriorPurchaseData.MostRecentPriorPurchaseDate,'1/1/1900') = '1/1/1900'
			          THEN 'No'
			          ELSE 'Yes'
					  END
			END MemberHasPurchasedProductPriorToReportDateRange

  FROM dbo.vTranItem TI
  JOIN dbo.vMMSTran MMST
       ON TI.MMSTranID = MMST.MMSTranID
  JOIN dbo.vClub C
       ON MMST.ClubID = C.ClubID
  JOIN dbo.vMember M
       ON MMST.MemberID = M.MemberID
  LEFT JOIN vEmailAddressStatus EAS
       ON M.EmailAddress = EAS.EmailAddress
      AND EAS.StatusFromDate <= GetDate()
      AND EAS.StatusThruDate > GetDate()
  LEFT JOIN vValCommunicationPreferenceStatus VCPS
       ON EAS.ValCommunicationPreferenceStatusID = VCPS.ValCommunicationPreferenceStatusID
  JOIN dbo.vValMemberType VMT
       ON VMT.ValMemberTypeID = M.ValMemberTypeID
  JOIN dbo.vProduct P
       ON TI.ProductID = P.ProductID
  JOIN #Products PS 
       ON P.ProductID = PS.ProductID
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vMembershipAddress MA
       ON MS.MembershipID = MA.MembershipID
  JOIN dbo.vDepartment D
       ON P.DepartmentID = D.DepartmentID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  LEFT JOIN dbo.vValState VS
       ON MA.ValStateID = VS.ValStateID
  LEFT JOIN dbo.vValCountry VC
       ON MA.ValCountryID = VC.ValCountryID
  LEFT JOIN dbo.vMemberPhoneNumbers MPN
       ON MS.MembershipID = MPN.MembershipID
  LEFT JOIN dbo.vMembershipCommunicationPreference MCP
       ON MS.MembershipID = MCP.MembershipID
  LEFT JOIN dbo.vValCommunicationPreference VCP
       ON MCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID
  JOIN #Clubs CI
       ON C.ClubID = CI.ClubID
  LEFT JOIN vEmployee POSEmployee
       ON MMST.EmployeeID = POSEmployee.EmployeeID
  LEFT JOIN #SaleCommission
       ON TI.TranItemID = #SaleCommission.TranItemID
  LEFT JOIN vSaleCommission SC
       ON SC.TranItemID = #SaleCommission.TranItemID
   AND SC.SaleCommissionID = #SaleCommission.SaleCommissionID
  LEFT JOIN vEmployee CommissionEmployee
       ON SC.EmployeeID = CommissionEmployee.EmployeeID
  LEFT JOIN vEmployee EmployeeMember
       ON M.MemberID = EmployeeMember.MemberID
  LEFT JOIN #PriorPurchaseData  #PriorPurchaseData
       ON M.MemberID = #PriorPurchaseData.MemberID
	   AND P.ProductID = #PriorPurchaseData.ProductID
 WHERE 
       MMST.PostDateTime BETWEEN @StartDate AND @EndDate AND
       MMST.TranVoidedID IS NULL AND             
       M.ActiveFlag = 1
	 AND (
		   (POSEmployee.EmployeeID = -5 and @myLTBucksFilter = 'myLT Buck$ Only')
			OR
		   (POSEmployee.EmployeeID is Null and @myLTBucksFilter ='Exclude myLT Buck$')
			OR
		   (POSEmployee.EmployeeID <> -5 and @myLTBucksFilter ='Exclude myLT Buck$')
			OR
		   (@myLTBucksFilter = 'Not Limited by myLT Buck$'))   

 GROUP BY C.ClubName, M.MemberID, M.FirstName, M.LastName, TI.ItemAmount,      
	   TI.Quantity, MMST.PostDateTime,
       MMST.TranDate, P.Description, TI.TranItemID,
       M.MembershipID, VMT.Description,
       MA.Addressline1, MA.Addressline2, MA.City, MA.Zip,
       VS.Abbreviation, VC.Abbreviation,
       M.EmailAddress, MPN.HomePhoneNumber,
       MPN.BusinessPhoneNumber, D.Description,
       VMS.Description,
       POSEmployee.EmployeeID, POSEmployee.FirstName, POSEmployee.LastName,
       CommissionEmployee.EmployeeID, CommissionEmployee.FirstName, CommissionEmployee.LastName,
	   VCC.CurrencyCode, #PlanRate.PlanRate, #ToUSDPlanRate.PlanRate,
	   M.DOB,
       M.Gender,
       EmployeeMember.EmployeeID,
	   CASE WHEN @IncludePriorPurchaseInfoFlag = 'N'
	        THEN ' '
            WHEN @IncludePriorPurchaseInfoFlag = 'Y'	
			THEN CASE WHEN IsNull(#PriorPurchaseData.MostRecentPriorPurchaseDate,'1/1/1900') = '1/1/1900'
			          THEN 'No'
			          ELSE 'Yes'
					  END
			END

DROP TABLE #Products
DROP TABLE #tmpList
DROP TABLE #Clubs
DROP TABLE #SaleCommission
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate
DROP TABLE #PurchasingMembersInPeriod
DROP TABLE #PriorPurchaseData

END






