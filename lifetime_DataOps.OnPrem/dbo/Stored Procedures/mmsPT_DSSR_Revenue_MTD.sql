





CREATE PROC [dbo].[mmsPT_DSSR_Revenue_MTD] (
         @ClubList VARCHAR(8000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/*	=============================================
	Object:			dbo.mmsPT_DSSR_Revenue_MTD
	Author:			
	Create date: 	
	Description:		Returns a set of revenue tran records for the PT Dept. DSSR report
	Parameters:		a preset "1st of Prior Month through yesterday's date" and
					a preset list of departments for all clubs, 
					also a list of club names or 'All'
	Modified date:	1/16/2013 BSD: Updated logic to use ReportDimProduct and ReportDimReportingHierarchy in place of ProductGroup
	                1/14/2013 update 2 hard coded strings for Life Time Weight Loss Department
	                11/14/2012 BSD: Added handling for Corporate Transfer transactions ($0 sales)
	                6/21/2012 BSD: added department Run-Cycle-Tri Training
	                12/9/2011 BSD: Updated OldVsNewBusiness calculation to be prior 6 months instead of prior 3 months
	                11/18/2011 BSD: Added 13 new columns. QC#806
	                6/29/2011 BSD: Added Foreign Currency support, removed obsolete column ItemSalesTax
                    5/4/2011 BSD: Removing 'Mixed Combat Arts' QC7087
                    4/4/2011 BSD: Including ProductID 5234 QC6963
                    3/24/2011 BSD: Excluding ProductID 5234 QC6883
                    2/21/2011 BSD: return add'l column RevenueReportingDepartment.  Remove filter for ProductID = 286.
                    12/29/2010 BSD: Added 'Mixed Combat Arts' to list of departments, and filtering out 'LT ENDurance'
                    1/28/2010 GRB: fix QC#4276; changed JOIN to LEFT JOIN so as not to inadvertently exclude Nutrition products from result set/report;
					12/19/2008 GRB: removed 'Polar%' wildcard and added 'Merchandise' to list of departments; dbcr_3993 deploying 1/14/2009 

	Exec mmsPT_DSSR_Revenue_MTD 'All'
	=============================================	*/

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

DECLARE @StartDate AS DATETIME
DECLARE @ENDDate AS DATETIME
DECLARE @ReportDate AS DATETIME
DECLARE @FirstOfPriorMonth AS DATETIME
DECLARE @FirstOf6MonthsPrior DATETIME
DECLARE @FirstOfCurrentMonth DATETIME

SET @StartDate = CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110)
SET @ENDDate = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)
SET @ReportDate = Replace(Substring(convert(varchar,getdate()-1,100),1,6)+', '+Substring(convert(varchar,getdate()-1,100),8,4),'  ',' ')
SET @FirstOfPriorMonth = DATEADD(m,-1,CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110))
SET @FirstOf6MonthsPrior = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(m,-6, GETDATE() - DAY(GETDATE()-1)),110),110)
SET @FirstOfCurrentMonth = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE() - DAY(GETDATE()-1),110),110)

--- This query segment returns members who have a tracked product transaction on record in the past 6 months
--- Yet, this code eliminates members whose transactions were fully offset in the same 6 months ( this would occur through a refund or negative adj. )
--- While still counting them if they also had zero dollar transactions
--- This code also eliminates transactions entered by employee # -5 "Loyalty Program"
CREATE TABLE #OldBusinessMembers1 (MemberID  INT, Amount DECIMAL(10,2),ABVAmount DECIMAL(10,2),ZeroTranFlag INT,SNS_OldBusiness_Flag INT,TrainingSvc_OldBusiness_Flag INT,AssessmentSvc_OldBusiness_Flag INT,Products_OldBusiness_Flag INT,CorporateTransferCount INT )
INSERT INTO #OldBusinessMembers1 (MemberID,Amount,ABVAmount,SNS_OldBusiness_Flag,TrainingSvc_OldBusiness_Flag,AssessmentSvc_OldBusiness_Flag,Products_OldBusiness_Flag,ZeroTranFlag,CorporateTransferCount)
SELECT MMSR.MemberID, 
       Sum(MMSR.ItemAmount),
       Sum(ABS(MMSR.ItemAmount)),
       Max(CASE WHEN ReportDimReportingHierarchy.ProductGroupName = 'SNS'                   
            THEN 1  
            ELSE 0
            END),
       Max(CASE WHEN (ReportDimReportingHierarchy.SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')
                  or ReportDimReportingHierarchy.DepartmentName in('Pilates','Personal Training','90 Day Weight Loss','Nutrition Services','MyHealth Check','MyHealth Score'))                    
            THEN 1  
            ELSE 0
            END),
       Max(CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Lab Testing','Metabolic Assessments')                    
            THEN 1  
            ELSE 0
            END),
       Max(CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Devices','PT Nutritionals')                     
            THEN 1  
            ELSE 0
            END),
       Sum(CASE WHEN MMSR.ItemAmount = 0 THEN 1 ELSE 0 END),
       Sum(CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN 1 ELSE 0 END)
  FROM vMMSRevenueReportSummary MMSR
  JOIN vReportDimProduct ReportDimProduct
    ON MMSR.ProductID = ReportDimProduct.MMSProductID
  JOIN vReportDimReportingHierarchy ReportDimReportingHierarchy
    ON ReportDimProduct.DimReportingHierarchyKey = ReportDimReportingHierarchy.DimReportingHierarchyKey
 --WHERE ReportDimProduct.MMSDepartmentDescription IN ('Mixed Combat Arts','Run-Cycle-Tri Training','Mind Body','Life Time Weight Loss','Merchandise','Personal Training','Nutrition Coaching') --D.DepartmentID in (6,7,9,10,19,33,34)   ------Life Time Weight Loss, Merchandise, Personal Training, Mind Body, Nutrition Coaching, Mixed Combat Arts (QC#1838)
 WHERE ReportDimReportingHierarchy.DivisionName = 'Personal Training'
   AND ReportDimProduct.ReportNewBusinessOldBusinessFlag = 'Y'    --AND PG.Old_vs_NewBusiness_TrackingFlag = 1
   AND MMSR.PostDateTime >= @FirstOf6MonthsPrior
   AND MMSR.PostDateTime < @FirstOfCurrentMonth
   AND MMSR.EmployeeID <> -5 --3/4/2011 BSD
 GROUP BY MMSR.MemberID

CREATE TABLE #OldBusinessMembers (MemberID INT,SNS_OldBusiness_Flag INT,TrainingSvc_OldBusiness_Flag INT,AssessmentSvc_OldBusiness_Flag INT,Products_OldBusiness_Flag INT)
INSERT INTO #OldBusinessMembers (MemberID,SNS_OldBusiness_Flag,TrainingSvc_OldBusiness_Flag,AssessmentSvc_OldBusiness_Flag,Products_OldBusiness_Flag)
SELECT MemberID,SNS_OldBusiness_Flag,TrainingSvc_OldBusiness_Flag,AssessmentSvc_OldBusiness_Flag,Products_OldBusiness_Flag
  FROM #OldBusinessMembers1
 WHERE Amount <> 0 
    OR (Amount = 0 AND CorporateTransferCount <> 0) --11/14/2012 Corporate transfer
 GROUP BY MemberID,SNS_OldBusiness_Flag,TrainingSvc_OldBusiness_Flag,AssessmentSvc_OldBusiness_Flag,Products_OldBusiness_Flag

SELECT Item ClubName
  INTO #Clubs
  FROM fnParsePipeList(@ClubList)

BEGIN
SELECT DISTINCT
       PostingClubName, 
       CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
            ELSE MMSR.ItemAmount END LocalCurrency_ItemAmount,
       CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
            ELSE MMSR.ItemAmount END * USDPlanExchangeRate.PlanExchangeRate as ItemAmount,
       DeptDescription, 
       MMSR.ProductDescription,
       MembershipClubname,
       PostingClubid, 
       MMSR.DrawerActivityID, 
       MMSR.PostDateTime, 
       MMSR.TranDate, 
       TranTypeDescription, 
       MMSR.ValTranTypeID, 
       MMSR.MemberID, 
       MMSR.EmployeeID,
       PostingRegionDescription,
       MemberFirstname, 
       MemberLastname,
       EmployeeFirstname, 
       EmployeeLastname,
       ReasonCodeDescription,
       MMSR.TranItemID, 
       TranMemberJoinDate, 
       MMSR.MembershipID, 
       MMSR.ProductID,
       TranClubid, 
       MMSR.Quantity,
       @ReportDate ReportDate,
       CASE WHEN MMSR.PostDateTime >=@ReportDate AND MMSR.PostDateTime < @ENDDate THEN 1 ELSE 0 END TodayFlag,
       CASE WHEN MMSR.PostDateTime < @StartDate THEN 1 ELSE 0 END PriorMonthTransactionFlag,
       P.PackageProductFlag,
       ReportDimProduct.ReportNewBusinessOldBusinessFlag,-- vProductGroup.Old_vs_NewBusiness_TrackingFlag,
       ReportDimProduct.DimReportingHierarchyKey,--vValProductGroup.ValProductGroupID,
       ReportDimReportingHierarchy.ProductGroupName,--vValProductGroup.Description AS ValProductGroupDescription,
       CAST(CONVERT(DATETIME, CONVERT(VARCHAR(10), MMSR.PostDateTime, 101) , 101) - 
            CONVERT(DATETIME, CONVERT(VARCHAR(10), vMembership.CreatedDateTime, 101) , 101) AS INT) AS MembershipAgeInDays_AtPostDate,
       ReportDimReportingHierarchy.DepartmentName,--vValProductGroup.RevenueReportingDepartment,  --2/21/2011
       ISNULL(MMSR.LocalCurrencyCode,'USD') LocalCurrencyCode,
       USDPlanExchangeRate.PlanExchangeRate PlanRate,
       MRP.ActivationDate as FirstAssessmentDate_RecurrentProduct,
       CASE WHEN ReportDimProduct.RevenueProductGroupName = 'PT' and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null THEN 1  ---Note: DEV and PROD HierarchyKeys are not in sync, switch to using group name
            ELSE 0
            END OneOnOnePT_EFTTranFlag,     
       CASE WHEN (ReportDimReportingHierarchy.SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')
                  or ReportDimReportingHierarchy.DepartmentName in('Pilates','Personal Training','90 Day Weight Loss','Nutrition Services','MyHealth Check','MyHealth Score'))                    
                  and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null THEN 1  
            ELSE 0
            END TrainingSvc_EFTTranFlag,
       CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Lab Testing','Metabolic Assessments')                    
                  and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null THEN 1  
            ELSE 0
            END AssessmentSvc_EFTTranFlag,     
       CASE WHEN ReportDimProduct.RevenueProductGroupName = 'PT' and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) THEN 1
            ELSE 0
            END OneOnOnePT_ResignTranFlag,  
       CASE WHEN (ReportDimReportingHierarchy.SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')
                  or ReportDimReportingHierarchy.DepartmentName in('Pilates','Personal Training','90 Day Weight Loss','Nutrition Services','MyHealth Check','MyHealth Score'))  
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) THEN 1
            ELSE 0
            END TrainingSvc_ResignTranFlag,  
       CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Lab Testing','Metabolic Assessments') 
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) THEN 1
            ELSE 0
            END AssessmentSvc_ResignTranFlag, 
       CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Devices','PT Nutritionals') 
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) THEN 1
            ELSE 0
            END Products_ResignTranFlag,   
       CASE WHEN ReportDimProduct.RevenueProductGroupName != 'PT' and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null THEN 1
            ELSE 0
            END NonOneOnOnePT_EFTTranFlag,       
       CASE WHEN ReportDimProduct.RevenueProductGroupName != 'PT' and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) THEN 1
            ELSE 0
            END NonOneOnOnePT_ResignTranFlag,
       CASE WHEN ReportDimProduct.RevenueProductGroupName = 'PT' and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null 
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' 
                            THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate AS OneOnOnePT_EFTTran_ItemAmount,
       CASE WHEN (ReportDimReportingHierarchy.SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')
                  or ReportDimReportingHierarchy.DepartmentName in('Pilates','Personal Training','90 Day Weight Loss','Nutrition Services','MyHealth Check','MyHealth Score')) 
                  and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null 
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' 
                            THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate AS TrainingSvc_EFTTran_ItemAmount,
       CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Lab Testing','Metabolic Assessments') 
                  and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null 
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' 
                            THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate AS AssessmentSvc_EFTTran_ItemAmount,
       CASE WHEN ReportDimProduct.RevenueProductGroupName = 'PT' and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) 
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate AS OneOnOnePT_ResignTran_ItemAmount,
       CASE WHEN (ReportDimReportingHierarchy.SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')
                  or ReportDimReportingHierarchy.DepartmentName in('Pilates','Personal Training','90 Day Weight Loss','Nutrition Services','MyHealth Check','MyHealth Score'))
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) 
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate AS TrainingSvc_ResignTran_ItemAmount,
       CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Lab Testing','Metabolic Assessments')
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) 
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate AS AssessmentSvc_ResignTran_ItemAmount, 
       CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Devices','PT Nutritionals')
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) 
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate AS Products_ResignTran_ItemAmount, 
       CASE WHEN ReportDimProduct.RevenueProductGroupName != 'PT' and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate AS NonOneOnOnePT_EFTTran_ItemAmount,   
       CASE WHEN ReportDimProduct.RevenueProductGroupName != 'PT' and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge'))
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate AS NonOneOnOnePT_ResignTran_ItemAmount,
       CASE WHEN ReportDimProduct.RevenueProductGroupName = 'PT' and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END AS LocalCurrency_OneOnOnePT_EFTTran_ItemAmount,
       CASE WHEN (ReportDimReportingHierarchy.SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')
                  or ReportDimReportingHierarchy.DepartmentName in('Pilates','Personal Training','90 Day Weight Loss','Nutrition Services','MyHealth Check','MyHealth Score')) 
                  and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END AS LocalCurrency_TrainingSvc_EFTTran_ItemAmount,
       CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Lab Testing','Metabolic Assessments')
                  and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END AS LocalCurrency_AssessmentSvc_EFTTran_ItemAmount,
       CASE WHEN ReportDimProduct.RevenueProductGroupName = 'PT' and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge'))
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END LocalCurrency_OneOnOnePT_ResignTran_ItemAmount, 
       CASE WHEN (ReportDimReportingHierarchy.SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')
                  or ReportDimReportingHierarchy.DepartmentName in('Pilates','Personal Training','90 Day Weight Loss','Nutrition Services','MyHealth Check','MyHealth Score')) 
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge'))
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END LocalCurrency_TrainingSvc_ResignTran_ItemAmount,
       CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Lab Testing','Metabolic Assessments') 
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge'))
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END LocalCurrency_AssessmentSvc_ResignTran_ItemAmount,
       CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Devices','PT Nutritionals') 
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge'))
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END LocalCurrency_Products_ResignTran_ItemAmount,
       CASE WHEN ReportDimProduct.RevenueProductGroupName != 'PT' and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END LocalCurrency_NonOneOnOnePT_EFTTran_ItemAmount,   
       CASE WHEN ReportDimProduct.RevenueProductGroupName != 'PT' and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge'))
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END LocalCurrency_NonOneOnOnePT_ResignTran_ItemAmount,
       #OldBusinessMembers.MemberID MemberID_OldBusiness,
       #OldBusinessMembers.SNS_OldBusiness_Flag,
       #OldBusinessMembers.TrainingSvc_OldBusiness_Flag,
       #OldBusinessMembers.AssessmentSvc_OldBusiness_Flag,
       #OldBusinessMembers.Products_OldBusiness_Flag,
       CASE WHEN MMSR.TranTypeDescription <> 'Refund' THEN 0
            WHEN MMSTran2.PostDateTime IS NULL THEN 1
            WHEN MMSTran2.PostDateTime >= @StartDate AND MMSTran2.PostDateTime < @ENDDate THEN 0
            ELSE 1 END RefundForPriorMonthTransactionFlag,
       ReportDimProduct.CorporateTransferFlag,
       ReportDimProduct.CorporateTransferMultiplier
  FROM vMMSRevenueReportSummary MMSR 
  JOIN #Clubs CS 
    ON MMSR.PostingClubName = CS.ClubName OR CS.ClubName = 'All'
  JOIN vProduct P 
    ON P.ProductID = MMSR.ProductID
  JOIN vReportDimProduct ReportDimProduct --11/14/2012 Corporate transfer
    ON MMSR.ProductID = ReportDimProduct.MMSProductID
  JOIN vReportDimReportingHierarchy ReportDimReportingHierarchy --1/16/2012 conversion to DimReportingHierarchy
    ON ReportDimProduct.DimReportingHierarchyKey = ReportDimReportingHierarchy.DimReportingHierarchyKey
  JOIN vMembership 
    ON vMembership.MembershipID = MMSR.MembershipID
  JOIN vClub C 
    ON MMSR.PostingClubID = C.ClubID
  JOIN vPlanExchangeRate USDPlanExchangeRate
    ON ISNULL(MMSR.LocalCurrencyCode,'USD') = USDPlanExchangeRate.FromCurrencyCode
   AND 'USD' = USDPlanExchangeRate.ToCurrencyCode
   AND YEAR(MMSR.PostDateTime) = USDPlanExchangeRate.PlanYear
  LEFT JOIN #OldBusinessMembers
    ON #OldBusinessMembers.MemberID = MMSR.MemberID
  LEFT JOIN vMembershipRecurrentProduct MRP
    On MMSR.ProductID = MRP.ProductID
    AND MMSR.MembershipID = MRP.MembershipID
    AND MMSR.ValTranTypeID = 1
    AND MRP.Price = MMSR.ItemAmount
    AND MRP.NumberOfSessions = MMSR.Quantity
    AND Convert(datetime,Convert(varchar,MMSR.PostDateTime,101),101) = Convert(datetime,Convert(varchar,MRP.Activationdate,101),101)
  JOIN vTranItem TI
    ON MMSR.TranItemID = TI.TranItemID
  LEFT JOIN vMMSTranRefund MTR
    ON TI.MMSTranID = MTR.MMSTranID
  LEFT JOIN vMMSTranRefundMMSTran MTRMT
    ON MTR.MMSTranRefundID = MTRMT.MMSTranRefundID
  LEFT JOIN vMMSTran MMSTran2
    ON MTRMT.OriginalMMSTranID = MMSTran2.MMSTranID
 WHERE ((MMSR.PostDateTime >= @StartDate AND MMSR.PostDateTime < @ENDDate)
         or 
        (MMSR.PostDateTime >= @FirstOfPriorMonth AND MMSR.PostDateTime < @StartDate 
            AND MMSR.TranMemberJoinDate >= @FirstOfPriorMonth AND MMSR.TranMemberJoinDate  < @StartDate))
  --AND ((MMSR.DeptDescription IN('Personal Training','Nutrition Coaching','Mind Body', 'Merchandise','Mixed Combat Arts','Run-Cycle-Tri Training','Life Time Weight Loss'))
  AND (ReportDimReportingHierarchy.DivisionName = 'Personal Training'
        And (MMSR.ItemAmount <> 0 
             OR (MMSR.ItemAmount = 0 AND MMSR.EmployeeID = -5) 
             OR (MMSR.ItemAmount = 0 AND ReportDimProduct.CorporateTransferFlag = 'Y'))) --11/14/2012 Corporate transfer  

                                            
END


 DROP TABLE #Clubs
 DROP TABLE #OldBusinessMembers

-- Report Logging
  UPDATE HyperionReportLog
  SET ENDDateTime = getdate()
  WHERE ReportLogID = @Identity

END





