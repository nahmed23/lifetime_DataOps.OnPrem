
--PackageSessionsDetail
CREATE PROC [dbo].[mmsPackage_SessionsDetail](
       @ClubIDs VARCHAR(1000),
       @StartDate DATETIME,
       @EndDate DATETIME,
       @MMSDeptIDList VARCHAR(1000), -- 2/25/2011 BSD
       @PartnerProgramList VARCHAR(2000) --2/25/2011 BSD
) 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/*	=============================================
Object:			dbo.mmsPackage_SessionsDetail
Author:			
Create date: 	
Description:	This query returns delivered sessions within a selected date range.
Modified date:	1/28/2013 BSD: changed ProductGroup to ReportDimProduct and ReportDimReportingHierarchy QC#2087
                02/25/2011 BSD: added parameter @MMSDeptIDList and @PartnerProgramList
                10/22/2010 BSD: Added 4 columns and 1 left join to result set
				11/17/2009 GRB: per QC# 4007, added MembershipID just before MemberID; 
					deploying 11/18/2009 via dbcr_5308
                09/16/2010 MLL:  RR 423 added additional columns to result set 
                    including discounts

exec mmsPackage_SessionsDetail '8|131|140','Nov 1, 2010','Nov 30, 2010','10','< Do Not Limit By Partner Program >'
EXEC mmsPackage_SessionsDetail '141', 'Apr 1, 2011', 'Apr 3, 2011', 'All', '< Do Not Limit By Partner Program >'
	=============================================	*/

/*
Section qSessionsDelivered ---- RR Member Connectivity Section 2), 3) 4) and new 4.5) ( FitPoint – First 30 Days) 
	1) DBCR required – Update the stored procedure “mmsPackage_SessionsDetail” 
		a) Join in view vMembership to return vMembership.CreatedDateTime.
		b) Return new data item “MembershipAgeInDaysAtDelivery” finding the number of days from the Membership.CreatedDateTime to the Session.DeliveredDateTime
		c) Change the case logic for the column “Half_Session_Flag” to flag any product with the text ’30 minute’ in the product description instead of using hard coded product IDs.  ---- RR Average Session Price 2)
		d) Return new data item MMST.EmployeeID as TransactionEmployeeID at the end of the Select statement.
		e) Left Join in view vProductGroup on vProductGroup.ProductID = vProduct.ProductID
		f) Left Join in view vValProductGroup on vProductGroup.ValProductGroupID = vValProductGroup.ValProductGroupID
		g) Return new data items vValProductGroup.ValProductGroupID and vValProductGroup.Description as ProgramProductGroupDescription
*/

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList(StringField VARCHAR(50))

CREATE TABLE #Clubs(ClubID INT)
IF @ClubIDs <> 'All'
BEGIN
	---- Parse the ClubIDs into a temp table
	EXEC procParseIntegerList @ClubIDs
	INSERT INTO #Clubs(ClubID) SELECT StringField FROM #tmpList
END
ELSE
BEGIN
   INSERT INTO #Clubs VALUES(0) -- all clubs
END  

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 0
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/


--Added 2/25/2011 BSD
TRUNCATE TABLE #tmpList
CREATE TABLE #DepartmentIDs (DepartmentID INT)
IF @MMSDeptIDList = 'All'
 BEGIN
  INSERT INTO #DepartmentIDS (DepartmentID) SELECT DepartmentID FROM vDepartment
 END
ELSE
 BEGIN
  EXEC procParseIntegerList @MMSDeptIDList
  INSERT INTO #DepartmentIDs SELECT StringField FROM #tmpList
 END

--Added 2/25/2011 BSD
TRUNCATE TABLE #tmpList
CREATE TABLE #PartnerPrograms (PartnerProgram Varchar(50))
EXEC procParseStringList @PartnerProgramList
INSERT INTO #PartnerPrograms (PartnerProgram) SELECT StringField FROM #tmpList

--This cursor query returns MemberID and a comma delimited list of Partner Programs 
--used for Member Reimbursement within @StarDate and @EndDate
CREATE TABLE #PartnerProgramMembers (MemberID INT, PartnerProgramList VARCHAR(2000))

DECLARE @CursorMemberID INT,
        @CursorPartnerProgramName VARCHAR(2000),
        @CurrentMemberID INT

DECLARE PartnerProgram_Cursor CURSOR LOCAL READ_ONLY FOR
SELECT DISTINCT MR.MemberID, RP.ReimbursementProgramName
FROM vMemberReimbursement MR
JOIN vReimbursementProgram RP
  ON MR.ReimbursementProgramID = RP.ReimbursementProgramID
JOIN #PartnerPrograms PP
  ON RP.ReimbursementProgramName = PP.PartnerProgram
WHERE MR.EnrollmentDate <= @EndDate
  AND (MR.TerminationDate >= @StartDate OR MR.TerminationDate IS NULL)
ORDER BY MR.MemberID, RP.ReimbursementProgramName

SET @CurrentMemberID = 0

OPEN PartnerProgram_Cursor
FETCH NEXT FROM PartnerProgram_Cursor INTO @CursorMemberID, @CursorPartnerProgramName
WHILE (@@FETCH_STATUS = 0)
  BEGIN
    IF @CursorMemberID <> @CurrentMemberID
      BEGIN
        INSERT INTO #PartnerProgramMembers (MemberID, PartnerProgramList) VALUES (@CursorMemberID,@CursorPartnerProgramName)
        SET @CurrentMemberID = @CursorMemberID
      END
    ELSE
      BEGIN
        UPDATE #PartnerProgramMembers
        SET PartnerProgramList = PartnerProgramList+', '+@CursorPartnerProgramName
        WHERE MemberID = @CursorMemberID
      END
    FETCH NEXT FROM PartnerProgram_Cursor INTO @CursorMemberID, @CursorPartnerProgramName
  END

CLOSE PartnerProgram_Cursor
DEALLOCATE PartnerProgram_Cursor

--- This query gathers discount data for all tranitem records for the period 
--- and club which have discount data

CREATE TABLE #TMPDiscount (
       TranItemID INT,
       ItemAmount MONEY,
       TotalDiscountAmount MONEY,
       ReceiptText1 VARCHAR(50),
       AppliedDiscountAmount1 MONEY,
       ReceiptText2 VARCHAR(50),
       AppliedDiscountAmount2 MONEY,
       ReceiptText3 VARCHAR(50),
       AppliedDiscountAmount3 MONEY,
       ReceiptText4 VARCHAR(50),
       AppliedDiscountAmount4 MONEY,
       ReceiptText5 VARCHAR(50),
       AppliedDiscountAmount5 MONEY)

DECLARE @TranItemID INT,
        @ItemAmount MONEY,
        @TotalDiscountAmount MONEY,
        @ReceiptText VARCHAR(50),
        @AppliedDiscountAmount MONEY,
        @TranItemDiscountID INT,
        @HOLDTranItemID INT,
        @Counter INT

SET @HOLDTranItemID = -1
SET @Counter = 1

DECLARE Discount_Cursor CURSOR LOCAL READ_ONLY FOR
SELECT TI.TranItemID, TI.ItemAmount, TI.ItemDiscountAmount as TotalDiscountAmount,SP.ReceiptText,TID.AppliedDiscountAmount, TID.TranItemDiscountID
  FROM vPackageSession S
   JOIN vPackage PKG
     ON S.PackageID = PKG.PackageID
   JOIN #Clubs tC
    On (S.ClubID = tC.ClubID OR tC.ClubID = 0)
  JOIN vTranItem TI
    ON PKG.TranItemID = TI.TranItemID
  JOIN vTranItemDiscount TID
    ON TID.TranItemID = TI.TranItemID
  JOIN vPricingDiscount PD
    ON PD.PricingDiscountID = TID.PricingDiscountID
  JOIN vSalesPromotion SP
    ON PD.SalesPromotionID = SP.SalesPromotionID
  JOIN vMMSTran MMST   
	ON MMST.MMSTranID = PKG.MMSTranID
  JOIN vProduct P  --2/25/2011 BSD
    ON PKG.ProductID = P.ProductID  --2/25/2011 BSD
  JOIN #DepartmentIDs  --2/25/2011 BSD
    ON P.DepartmentID = #DepartmentIDs.DepartmentID  --2/25/2011 BSD


  WHERE S.DeliveredDateTime >= @StartDate
   AND S.DeliveredDateTime <= @EndDate
   AND MMST.TranVoidedID IS NULL
 GROUP BY TI.TranItemID, TI.ItemAmount, TI.ItemDiscountAmount,SP.ReceiptText,TID.AppliedDiscountAmount, TID.TranItemDiscountID
   
 ORDER BY TI.TranItemID, TID.TranItemDiscountID 

OPEN Discount_Cursor
FETCH NEXT FROM Discount_Cursor INTO @TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount,@TranItemDiscountID
WHILE (@@FETCH_STATUS = 0)
    BEGIN

        IF @TranItemID != @HOLDTranItemID
            BEGIN
                INSERT INTO #TMPDiscount
                   (TranItemID, ItemAmount, TotalDiscountAmount, ReceiptText1, AppliedDiscountAmount1)
                VALUES (@TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount)
                SET @HOLDTranItemID = @TranItemID
                SET @Counter = 1
            END
        ELSE
            BEGIN
                SET @Counter = @Counter + 1
                IF @Counter = 2
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText2 = @ReceiptText, AppliedDiscountAmount2 = @AppliedDiscountAmount
                         WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 3
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText3 = @ReceiptText, AppliedDiscountAmount3 = @AppliedDiscountAmount
                          WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 4
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText4 = @ReceiptText, AppliedDiscountAmount4 = @AppliedDiscountAmount
                          WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 5
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText5 = @ReceiptText, AppliedDiscountAmount5 = @AppliedDiscountAmount
                         WHERE TranItemID = @TranItemID
                    END
                SET @HOLDTranItemID = @TranItemID
            END

    FETCH NEXT FROM Discount_Cursor INTO @TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount,@TranItemDiscountID
    END

CLOSE Discount_Cursor
DEALLOCATE Discount_Cursor

------  Return result set

SELECT RC.Clubname AS RevenueClub, 
       RC.Clubid AS RevenueClubID, 
       E.Employeeid,
       E.Firstname AS EmployeeFirstname, 
       E.Lastname AS EmployeeLastname,
       S.Packagesessionid AS SessionID, 
       S.Sessionprice * #PlanRate.PlanRate as Sessionprice,
	   S.Sessionprice as LocalCurrency_Sessionprice,
	   S.Sessionprice * #ToUSDPlanRate.PlanRate as USD_Sessionprice,
	   P.Productid, 
       P.Description AS ProductDescription, 
       M.Memberid, 
       M.Firstname AS MemberFirstname, 
       M.Lastname AS MemberLastname,  
       VPS.Description AS PackageStatusDescription, 
       PKG.Packageid, 
       S.Delivereddatetime as Deliverddatetime_Sort,
	   Replace(Substring(convert(varchar,S.Delivereddatetime,100),1,6)+', '+Substring(convert(varchar,S.Delivereddatetime,100),8,10)+' '+Substring(convert(varchar,S.Delivereddatetime,100),18,2),'  ',' ') as Delivereddatetime,
       SC.Clubname AS SaleClub, 
       SC.Clubid AS SaleClubid,
       R.Description AS RegionDescription,
       S.Comment, 
       EC.ClubName AS EmployeeHomeClub,
       CASE
           WHEN P.Description LIKE '%30 minute%'
                THEN 1
                ELSE 0
       END Half_Session_Flag,
       P.DepartmentID AS ProductDeptID, 
       @EndDate AS ReportingEndDateTime_Sort,
	   Replace(Substring(convert(varchar,@EndDate,100),1,6)+', '+Substring(convert(varchar,@EndDate,100),8,10)+' '+Substring(convert(varchar,@EndDate,100),18,2),'  ',' ') as ReportingEndDateTime,
       PKG.CreatedDateTime AS PackageCreatedDate,
       E1.FirstName+' '+E1.LastName AS TransactionEmployee,
       M.MembershipID, -- added 11/17/2009 GRB
       MS.CreatedDateTime as CreatedDateTime_Sort,
	   Replace(Substring(convert(varchar,MS.CreatedDateTime,100),1,6)+', '+Substring(convert(varchar,MS.CreatedDateTime,100),8,10)+' '+Substring(convert(varchar,MS.CreatedDateTime,100),18,2),'  ',' ') as CreatedDateTime,
       CAST(CONVERT(DATETIME, CONVERT(VARCHAR(10), S.DeliveredDateTime, 101) , 101) - 
       CONVERT(DATETIME, CONVERT(VARCHAR(10),MS.CreatedDateTime, 101) , 101) AS INT) AS MembershipAgeInDaysAtDelivery,
       NULL ValProductGroupID, 
       --NULL ProgramProductGroupDescription,
       DRH.ProductGroupName as ProgramProductGroupDescription,
       MMST.EmployeeID AS TransactionEmployeeID,
       RC.ClubName as ServiceClubName,
       RC.GLClubID as ServiceGLClubID,
       E.EmployeeID as DeliveredEmployeeID,
       E.FirstName as DeliveredEmployeeFirstName,
       E.LastName as DeliveredEmployeeLastName,
       EC.ClubName as DeliveredEmployeeHomeClubName,
       MC.ClubName as MembershipHomeClub,
       MP.Description as MembershipTypeDescription,
       TI.ItemDiscountAmount * #PlanRate.PlanRate as TotalDiscountAmount,
	   TI.ItemDiscountAmount as LocalCurrency_TotalDiscountAmount,
	   TI.ItemDiscountAmount * #ToUSDPlanRate.PlanRate as USD_TotalDiscountAmount,
       (TI.ItemDiscountAmount + TI.ItemAmount) * #PlanRate.PlanRate as GrossTranAmount,
	   (TI.ItemDiscountAmount + TI.ItemAmount) as LocalCurrency_GrossTranAmount,
	   (TI.ItemDiscountAmount + TI.ItemAmount) * #ToUSDPlanRate.PlanRate as USD_GrossTranAmount,
       TMP.AppliedDiscountAmount1 * #PlanRate.PlanRate as DiscountAmount1,
	   TMP.AppliedDiscountAmount1 as LocalCurrency_DiscountAmount1,
	   TMP.AppliedDiscountAmount1 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount1,
       TMP.AppliedDiscountAmount2 * #PlanRate.PlanRate as DiscountAmount2,
	   TMP.AppliedDiscountAmount2 as LocalCurrency_DiscountAmount2,
	   TMP.AppliedDiscountAmount2 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount2,
       TMP.AppliedDiscountAmount3 * #PlanRate.PlanRate as DiscountAmount3,
	   TMP.AppliedDiscountAmount3 as LocalCurrency_DiscountAmount3,
	   TMP.AppliedDiscountAmount3 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount3,
       TMP.AppliedDiscountAmount4 * #PlanRate.PlanRate as DiscountAmount4,
	   TMP.AppliedDiscountAmount4 as LocalCurrency_DiscountAmount4,
	   TMP.AppliedDiscountAmount4 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount4,
       TMP.AppliedDiscountAmount5 * #PlanRate.PlanRate as DiscountAmount5,
	   TMP.AppliedDiscountAmount5 as LocalCurrency_DiscountAmount5,
	   TMP.AppliedDiscountAmount5 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount5,       
	   TMP.ReceiptText1 as Discount1,	   
       TMP.ReceiptText2 as Discount2,	  	   
       TMP.ReceiptText3 as Discount3,	   
       TMP.ReceiptText4 as Discount4,	  
       TMP.ReceiptText5 as Discount5,	
       CO.CompanyName,
	   D.Description as Department,
	   EP.EmployeeID AS PackageEmployeeID,  --added 10/22/2010 BSD
	   EP.FirstName AS PackageEmployeeFirstName,  --added 10/22/2010 BSD
       EP.LastName AS PackageEmployeeLastName,  --added 10/22/2010 BSD
       @StartDate AS ReportingStartDateTime_Sort, --added 10/22/2010 BSD
	   Replace(Substring(convert(varchar,@StartDate,100),1,6)+', '+Substring(convert(varchar,@StartDate,100),8,10)+' '+Substring(convert(varchar,@StartDate,100),18,2),'  ',' ') as ReportingStartDateTime,
       CASE WHEN @PartnerProgramList = '< Do Not Limit By Partner Program >' --2/25/2011 BSD 
                 THEN 'Not limited by Partner Program' --2/25/2011 BSD 
            ELSE PPM.PartnerProgramList  --2/25/2011 BSD 
       END AS SelectedPartnerPrograms, --2/25/2011 BSD 
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode  	
  FROM dbo.vPackagesession S
  JOIN dbo.vClub RC
    ON S.Clubid = RC.Clubid
  JOIN vValCurrencyCode VCC
       ON RC.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(S.Delivereddatetime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(S.Delivereddatetime) = #ToUSDPlanRate.PlanYear
  JOIN #Clubs tC
    ON (RC.Clubid = tC.ClubID OR tC.ClubID = 0)
  JOIN dbo.vValRegion R
    ON RC.Valregionid = R.ValRegionID
  JOIN dbo.vEmployee E
    ON S.Deliveredemployeeid = E.Employeeid
  JOIN dbo.vClub EC
    ON E.ClubID = EC.ClubID  ---- To Get Employee Home Club
  JOIN dbo.vPackage PKG
    ON S.Packageid = PKG.Packageid
  JOIN dbo.vMember M
    ON PKG.Memberid = M.Memberid
  JOIN dbo.vProduct P
    ON PKG.Productid = P.Productid
  JOIN dbo.vValpackagestatus VPS
    ON PKG.Valpackagestatusid = VPS.Valpackagestatusid
  JOIN dbo.vClub SC
    ON PKG.Clubid = SC.Clubid
  JOIN vMMSTran MMST 
	ON MMST.MMSTranID = PKG.MMSTranID
  JOIN vTranItem TI
      ON PKG.TranItemID = TI.TranItemID
  LEFT JOIN dbo.vEmployee E1
    ON E1.Employeeid = MMST.Employeeid 
  JOIN vMembership MS
    ON MS.MembershipID = MMST.MembershipID
  JOIN vClub MC
    ON MS.ClubID = MC.ClubID
  JOIN vMembershipType MT
    ON MS.MembershipTypeID = MT.MembershipTypeID
  JOIN vProduct MP
    ON MT.ProductID = MP.ProductID
  JOIN vReportDimProduct DP --1/28/2013 BSD
    ON P.ProductID = DP.MMSProductID --1/28/2013 BSD
  JOIN vReportDimReportingHierarchy DRH --1/28/2013 BSD
    ON DP.DimReportingHierarchyKey = DRH.DimReportingHierarchyKey --1/28/2013 BSD
  LEFT JOIN vProductGroup 
    ON vProductGroup.ProductID = P.ProductID
  LEFT JOIN vValProductGroup 
    ON vProductGroup.ValProductGroupID = vValProductGroup.ValProductGroupID
  LEFT JOIN #TMPDiscount TMP
    ON TI.TranItemID = TMP.TranItemID
  LEFT JOIN vCompany CO
    ON MS.CompanyID = CO.CompanyID
  JOIN vDepartment D 
	 ON D.DepartmentID = P.DepartmentID 
  LEFT JOIN vEmployee EP --added 10/22/2010 BSD
	 ON PKG.EmployeeID = EP.EmployeeID --added 10/22/2010 BSD
  JOIN #DepartmentIDs  --2/25/2011 BSD
     ON D.DepartmentID = #DepartmentIDs.DepartmentID  --2/25/2011 BSD
  LEFT JOIN #PartnerProgramMembers PPM --2/25/2011 BSD
     ON M.MemberID = PPM.MemberID --2/25/2011 BSD
 WHERE S.Delivereddatetime >= @StartDate 
   AND S.Delivereddatetime <= @EndDate
   AND ISNULL(PPM.MemberID,'-999') = CASE WHEN @PartnerProgramList = '< Do Not Limit By Partner Program >' --2/28/2011 BSD
                                               THEN ISNULL(PPM.MemberID,'-999') --2/28/2011 BSD
                                          ELSE M.MemberID END --2/28/2011 BSD


DROP TABLE #Clubs
DROP TABLE #TmpList
DROP TABLE #TMPDiscount
DROP TABLE #DepartmentIDs 
DROP TABLE #PartnerPrograms
DROP TABLE #PartnerProgramMembers
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
