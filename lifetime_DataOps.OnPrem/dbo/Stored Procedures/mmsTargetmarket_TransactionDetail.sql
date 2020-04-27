
CREATE    PROC [dbo].[mmsTargetmarket_TransactionDetail] (
  @ClubList VARCHAR(8000),
  @ProductIDList VARCHAR(8000),
  @PostStartDate SMALLDATETIME,
  @PostEndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--
-- returns itemtran and membership details for the Target market Brio document
--
-- Parameters: a clubname, a List of product IDs and a start and end tranitem post date
-- EXEC [mmsTargetmarket_TransactionDetail] 'New Hope, MN', '3291|3292|3293|3294|3295|3296|3297|3298|3299|3300|3301|3302|3303|3304', 'Apr 1, 2011', 'Apr 2, 2011'
-- 07/16/2010 MLL: Add POS and Commission Employee Information
-- 3/13/2012 BSD: Changed DoNotEmail to new EmailSolicitationStatus


-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  CREATE TABLE #tmpList (StringField VARCHAR(80))
  CREATE TABLE #Clubs (ClubName VARCHAR(50))
  IF @ClubList <> 'All'
    BEGIN
      EXEC procParseStringList @ClubList
      INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList
      TRUNCATE TABLE #tmpList
    END
  ELSE
    BEGIN
      INSERT INTO #Clubs (ClubName) SELECT ClubName FROM dbo.vClub
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
  JOIN #Clubs ON C.ClubName = #Clubs.ClubName OR #Clubs.ClubName = 'All'
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@PostStartDate)
  AND PlanYear <= Year(@PostEndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@PostStartDate)
  AND PlanYear <= Year(@PostEndDate)
  AND ToCurrencyCode = 'USD'
/***************************************/

SELECT SC.TranItemID, MIN(SC.SaleCommissionID) AS SaleCommissionID
  INTO #SaleCommission
  FROM vTranItem TI
  JOIN vMMSTran MMST
       ON TI.MMSTranID = MMST.MMSTranID
  JOIN vSaleCommission SC
       ON TI.TranItemID = SC.TranItemID
 WHERE MMST.PostDateTime BETWEEN @PostStartDate AND @PostEndDate 
       AND MMST.TranVoidedID IS NULL 
 GROUP BY SC.TranItemID

SELECT C.ClubName, M.MemberID, M.FirstName, M.LastName,	   
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
       EmployeeMember.EmployeeID EmployeeMember_EmployeeID
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
       ON C.ClubName = CI.ClubName 
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
 WHERE 
--C.ClubName = @ClubName AND
       MMST.PostDateTime BETWEEN @PostStartDate AND @PostEndDate AND
       MMST.TranVoidedID IS NULL AND
      -- P.Description IN (SELECT Description FROM #Products) AND
       M.ActiveFlag = 1
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
       EmployeeMember.EmployeeID

DROP TABLE #Products
DROP TABLE #tmpList
DROP TABLE #Clubs
DROP TABLE #SaleCommission
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

