




CREATE PROC [dbo].[procCognos_PT_DSSR_OldAndNewBusinessSummaryByClub] 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/*	=============================================
	Object:			procCognos_PT_DSSR_OldAndNewBusinessSummaryByClub
	Author:			
	Create date: 	
	Description:		Returns a set of Old and New Business counts, amounts and Percentages Summarized by Club


	=============================================	*/

DECLARE @StartDate AS DATETIME
DECLARE @ENDDate AS DATETIME
DECLARE @ReportRunDateTime AS DATETIME
DECLARE @ReportDate AS VARCHAR(20)
DECLARE @FirstOfPriorMonth AS DATETIME
DECLARE @FirstOf6MonthsPrior DATETIME
DECLARE @FirstOfCurrentMonth DATETIME


SET @StartDate = CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110)
SET @ENDDate = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)
SET @ReportDate = Replace(Substring(convert(varchar,GETDATE()-1,100),1,6)+', '+Substring(convert(varchar,GETDATE()-1,100),8,4),'  ',' ')
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')
SET @FirstOfPriorMonth = DATEADD(m,-1,CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110))
SET @FirstOf6MonthsPrior = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(m,-6, GETDATE() - DAY(GETDATE()-1)),110),110)
SET @FirstOfCurrentMonth = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE() - DAY(GETDATE()-1),110),110)


--- This query segment returns members who have a tracked product transaction on record in the past 6 months
--- Yet, this code eliminates members whose transactions were fully offset in the same 6 months ( this would occur through a refund or negative adj. )
--- This code also eliminates transactions entered by employee # -5 "Loyalty Program"
CREATE TABLE #OldBusinessMembers1 (MemberID  INT, Amount DECIMAL(10,2),ABVAmount DECIMAL(10,2),SNS_OldBusiness_Flag INT,TrainingSvc_OldBusiness_Flag INT,AssessmentSvc_OldBusiness_Flag INT,Products_OldBusiness_Flag INT,CorporateTransferCount INT )
INSERT INTO #OldBusinessMembers1 (MemberID,Amount,ABVAmount,SNS_OldBusiness_Flag,TrainingSvc_OldBusiness_Flag,AssessmentSvc_OldBusiness_Flag,Products_OldBusiness_Flag,CorporateTransferCount)
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
       Sum(CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN 1 ELSE 0 END)
  FROM vMMSRevenueReportSummary MMSR
  JOIN vReportDimProduct ReportDimProduct
    ON MMSR.ProductID = ReportDimProduct.MMSProductID
  JOIN vReportDimReportingHierarchy ReportDimReportingHierarchy
    ON ReportDimProduct.DimReportingHierarchyKey = ReportDimReportingHierarchy.DimReportingHierarchyKey
 WHERE ReportDimReportingHierarchy.DivisionName = 'Personal Training'
   AND ReportDimProduct.ReportNewBusinessOldBusinessFlag = 'Y'    
   AND MMSR.PostDateTime >= @FirstOf6MonthsPrior
   AND MMSR.PostDateTime < @FirstOfCurrentMonth
   AND MMSR.EmployeeID <> -5 
 GROUP BY MMSR.MemberID




CREATE TABLE #OldBusinessMembers (MemberID INT,SNS_OldBusiness_Flag INT,TrainingSvc_OldBusiness_Flag INT,AssessmentSvc_OldBusiness_Flag INT,Products_OldBusiness_Flag INT)
INSERT INTO #OldBusinessMembers (MemberID,SNS_OldBusiness_Flag,TrainingSvc_OldBusiness_Flag,AssessmentSvc_OldBusiness_Flag,Products_OldBusiness_Flag)
SELECT MemberID,SNS_OldBusiness_Flag,TrainingSvc_OldBusiness_Flag,AssessmentSvc_OldBusiness_Flag,Products_OldBusiness_Flag
  FROM #OldBusinessMembers1
 WHERE Amount <> 0 
    OR (Amount = 0 AND CorporateTransferCount <> 0) 
 GROUP BY MemberID,SNS_OldBusiness_Flag,TrainingSvc_OldBusiness_Flag,AssessmentSvc_OldBusiness_Flag,Products_OldBusiness_Flag



-- recurrent products
SELECT  
	DISTINCT
	MRP.ProductID,
	MRP.MembershipID,
	MRP.ActivationDate AS ActivationDate,
	MRP.Price,
    MRP.NumberOfSessions
INTO #MembershipRecurrentProduct
 FROM  vMembershipRecurrentProduct MRP
  JOIN vReportDimProduct ReportDimProduct 
    ON MRP.ProductID = ReportDimProduct.MMSProductID
  JOIN vReportDimReportingHierarchy ReportDimReportingHierarchy 
    ON ReportDimProduct.DimReportingHierarchyKey = ReportDimReportingHierarchy.DimReportingHierarchyKey
WHERE 
ReportDimReportingHierarchy.DivisionName = 'Personal Training' AND 
MRP.ActivationDate <= @ENDDate and (MRP.TerminationDate >= @StartDate or MRP.TerminationDate IS NULL)
and MRP.ProductAssessedDateTime IS NOT NULL and MRP.ProductAssessedDateTime >= @StartDate



------ Members who purchase devices are considered "New Business" when calculating Total New Business, regardless of what other products were purchased
  ----- so we need to query for those members and be sure their month's purchases are not split between Total Old and Total New Business counts and amounts.
SELECT MMSR.MemberID, 
       Area.Description as PostingRegionDescription, 
       MMSR.PostingClubName, 
       MMSR.PostingClubid, 
	   C.ClubCode AS PostingClubCode, 
       CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Devices')  
			THEN 1 
		    ELSE 0 
			END AS NewBusinessMember_DevicePurchase

INTO #ResultsForTotalNewBusinessMember
  FROM vMMSRevenueReportSummary MMSR 
  JOIN vProduct P 
    ON P.ProductID = MMSR.ProductID
  JOIN vReportDimProduct ReportDimProduct 
    ON MMSR.ProductID = ReportDimProduct.MMSProductID
  JOIN vReportDimReportingHierarchy ReportDimReportingHierarchy 
    ON ReportDimProduct.DimReportingHierarchyKey = ReportDimReportingHierarchy.DimReportingHierarchyKey
  JOIN vMembership 
    ON vMembership.MembershipID = MMSR.MembershipID	
  JOIN vClub C 
    ON MMSR.PostingClubID = C.ClubID
  Join vValPTRCLArea Area
    On C.ValPTRCLAreaID = Area.ValPTRCLAreaID
  LEFT JOIN #OldBusinessMembers
    ON #OldBusinessMembers.MemberID = MMSR.MemberID
  JOIN vTranItem TI
    ON MMSR.TranItemID = TI.TranItemID
  LEFT JOIN vMMSTranRefund MTR
    ON TI.MMSTranID = MTR.MMSTranID
  LEFT JOIN vMMSTranRefundMMSTran MTRMT
    ON MTR.MMSTranRefundID = MTRMT.MMSTranRefundID
  LEFT JOIN vMMSTran MMSTran2
    ON MTRMT.OriginalMMSTranID = MMSTran2.MMSTranID

 WHERE (MMSR.PostDateTime >= @StartDate AND MMSR.PostDateTime < @ENDDate)
  AND    ReportDimReportingHierarchy.DepartmentName in('Devices')
  And ((MMSR.ItemAmount <> 0 AND MMSR.EmployeeID <> -5)
             OR (MMSR.ItemAmount = 0 AND ReportDimProduct.CorporateTransferFlag = 'Y'))
  AND  ReportDimProduct.ReportNewBusinessOldBusinessFlag = 'Y'	 
  AND NOT (MMSR.TranTypeDescription ='Refund' AND (MMSTran2.PostDateTime IS NULL OR MMSTran2.PostDateTime < @StartDate)) -- RefundForPriorMonthTransactionFlag
 GROUP BY 
       Area.Description, 
       MMSR.PostingClubName, 
       MMSR.PostingClubid, 
	   C.ClubCode,
	   ReportDimReportingHierarchy.DepartmentName, 
       MMSR.MemberID


SELECT --DISTINCT

       MMSR.MemberID, 
       Area.Description as PostingRegionDescription, 
       MMSR.PostingClubName, 
       MMSR.PostingClubid, 
	   C.ClubCode AS PostingClubCode, 
	   
       SUM(CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
            ELSE MMSR.ItemAmount END) AS LocalCurrency_ItemAmount,
       
       SUM(CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
            ELSE MMSR.ItemAmount END * USDPlanExchangeRate.PlanExchangeRate) AS ItemAmount,

	   SUM(CASE WHEN #DefaultTotalNewBusinessMember.NewBusinessMember_DevicePurchase = 1 OR #OldBusinessMembers.MemberID IS NULL 
			THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
                 ELSE MMSR.ItemAmount END * USDPlanExchangeRate.PlanExchangeRate 
		    ELSE 0 
			END) AS NewBusiness_ItemAmount,

	   SUM(CASE WHEN #DefaultTotalNewBusinessMember.NewBusinessMember_DevicePurchase = 1 OR #OldBusinessMembers.MemberID IS NULL 
			THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
                 ELSE MMSR.ItemAmount END
		    ELSE 0 
			END) AS LocalCurrency_NewBusiness_ItemAmount,

	   SUM(CASE WHEN IsNull(#DefaultTotalNewBusinessMember.NewBusinessMember_DevicePurchase,0)=0  AND #OldBusinessMembers.MemberID IS NOT NULL
			THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
                 ELSE MMSR.ItemAmount END * USDPlanExchangeRate.PlanExchangeRate 
		    ELSE 0 
			END) AS OldBusiness_ItemAmount,

	   SUM(CASE WHEN IsNull(#DefaultTotalNewBusinessMember.NewBusinessMember_DevicePurchase,0)=0  AND #OldBusinessMembers.MemberID IS NOT NULL
			THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
                 ELSE MMSR.ItemAmount END
		    ELSE 0 
			END) AS LocalCurrency_OldBusiness_ItemAmount,

	   SUM(CASE WHEN  ReportDimReportingHierarchy.ProductGroupName = 'SNS'  
	              and (#OldBusinessMembers.SNS_OldBusiness_Flag = 0 or #OldBusinessMembers.SNS_OldBusiness_Flag IS NULL)
	        THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
					 ELSE MMSR.ItemAmount END * USDPlanExchangeRate.PlanExchangeRate 
			ELSE 0 
			END) AS SNS_NewBusiness_ItemAmount,

	   SUM(CASE WHEN  ReportDimReportingHierarchy.ProductGroupName = 'SNS'  
	              and (#OldBusinessMembers.SNS_OldBusiness_Flag = 0 or #OldBusinessMembers.SNS_OldBusiness_Flag IS NULL)
	        THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
					 ELSE MMSR.ItemAmount END
			ELSE 0 
			END) AS LocalCurrency_SNS_NewBusiness_ItemAmount,

	   SUM(CASE WHEN  ReportDimReportingHierarchy.ProductGroupName = 'SNS' and #OldBusinessMembers.SNS_OldBusiness_Flag = 1
	        THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
					 ELSE MMSR.ItemAmount END * USDPlanExchangeRate.PlanExchangeRate 
			ELSE 0 
			END) AS SNS_OldBusiness_ItemAmount,

	   SUM(CASE WHEN  ReportDimReportingHierarchy.ProductGroupName = 'SNS' and #OldBusinessMembers.SNS_OldBusiness_Flag = 1
	        THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
					 ELSE MMSR.ItemAmount END 
			ELSE 0 
			END) AS LocalCurrency_SNS_OldBusiness_ItemAmount,
     
	   SUM(CASE WHEN (ReportDimReportingHierarchy.SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')
                  or ReportDimReportingHierarchy.DepartmentName in('Pilates','Personal Training','90 Day Weight Loss','Nutrition Services','MyHealth Check','MyHealth Score'))   -- Training Services
				 and (TrainingSvc_OldBusiness_Flag IS NULL OR TrainingSvc_OldBusiness_Flag = 0) -- new business
	        THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
					 ELSE MMSR.ItemAmount END * USDPlanExchangeRate.PlanExchangeRate 
			ELSE 0 
			END) AS TrainingSvc_NewTran_ItemAmount,

	   SUM(CASE WHEN (ReportDimReportingHierarchy.SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')
                  or ReportDimReportingHierarchy.DepartmentName in('Pilates','Personal Training','90 Day Weight Loss','Nutrition Services','MyHealth Check','MyHealth Score'))   -- Training Services
				 and (TrainingSvc_OldBusiness_Flag IS NULL OR TrainingSvc_OldBusiness_Flag = 0) -- new business
	        THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
					 ELSE MMSR.ItemAmount END
			ELSE 0 
			END) AS LocalCurrency_TrainingSvc_NewTran_ItemAmount,

	   SUM(CASE WHEN (ReportDimReportingHierarchy.DepartmentName in ('Lab Testing','Metabolic Assessments')    
				 and (AssessmentSvc_OldBusiness_Flag IS NULL OR AssessmentSvc_OldBusiness_Flag = 0)) -- new business
	        THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
					 ELSE MMSR.ItemAmount END * USDPlanExchangeRate.PlanExchangeRate 
			ELSE 0 
			END) AS AssessmentSvc_NewTran_ItemAmount,
			
	   SUM(CASE WHEN (ReportDimReportingHierarchy.DepartmentName in ('Lab Testing','Metabolic Assessments')    
				 and (AssessmentSvc_OldBusiness_Flag IS NULL OR AssessmentSvc_OldBusiness_Flag = 0)) -- new business
	        THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
					 ELSE MMSR.ItemAmount END
			ELSE 0 
			END) AS LocalCurrency_AssessmentSvc_NewTran_ItemAmount,	
					
	   SUM(CASE WHEN (ReportDimReportingHierarchy.DepartmentName in('Devices','PT Nutritionals') 
				 and (Products_OldBusiness_Flag IS NULL OR Products_OldBusiness_Flag = 0)) -- new business
	        THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
					 ELSE MMSR.ItemAmount END * USDPlanExchangeRate.PlanExchangeRate 
			ELSE 0 
			END) AS Products_NewTran_ItemAmount,

	   SUM(CASE WHEN (ReportDimReportingHierarchy.DepartmentName in('Devices','PT Nutritionals') 
				 and (Products_OldBusiness_Flag IS NULL OR Products_OldBusiness_Flag = 0)) -- new business
	        THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier 
					 ELSE MMSR.ItemAmount END
			ELSE 0 
			END) AS LocalCurrency_Products_NewTran_ItemAmount,
	   
	   -- EFTTranAmount		  
       SUM(CASE WHEN (ReportDimReportingHierarchy.SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')
                  or ReportDimReportingHierarchy.DepartmentName in('Pilates','Personal Training','90 Day Weight Loss','Nutrition Services','MyHealth Check','MyHealth Score')) 
                  and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null and #OldBusinessMembers.TrainingSvc_OldBusiness_Flag = 1
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' 
                            THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate) AS TrainingSvc_EFTTran_ItemAmount,

       SUM(CASE WHEN (ReportDimReportingHierarchy.SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')
                  or ReportDimReportingHierarchy.DepartmentName in('Pilates','Personal Training','90 Day Weight Loss','Nutrition Services','MyHealth Check','MyHealth Score')) 
                  and MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null and #OldBusinessMembers.TrainingSvc_OldBusiness_Flag = 1
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' 
                            THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END ) AS LocalCurrency_TrainingSvc_EFTTran_ItemAmount,

       SUM(CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Lab Testing','Metabolic Assessments') 
                  and (MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null) and #OldBusinessMembers.AssessmentSvc_OldBusiness_Flag = 1
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' 
                            THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate) AS AssessmentSvc_EFTTran_ItemAmount,

       SUM(CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Lab Testing','Metabolic Assessments') 
                  and (MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Null) and #OldBusinessMembers.AssessmentSvc_OldBusiness_Flag = 1
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' 
                            THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END ) AS LocalCurrency_AssessmentSvc_EFTTran_ItemAmount,
       
	   -- ResignTranAmount
       SUM(CASE WHEN (ReportDimReportingHierarchy.SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')
                  or ReportDimReportingHierarchy.DepartmentName in('Pilates','Personal Training','90 Day Weight Loss','Nutrition Services','MyHealth Check','MyHealth Score'))
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) and #OldBusinessMembers.TrainingSvc_OldBusiness_Flag =1
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate) AS TrainingSvc_ResignTran_ItemAmount,

       SUM(CASE WHEN (ReportDimReportingHierarchy.SubdivisionName in('Endurance','Group Training','Mixed Combat Arts')
                  or ReportDimReportingHierarchy.DepartmentName in('Pilates','Personal Training','90 Day Weight Loss','Nutrition Services','MyHealth Check','MyHealth Score'))
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) and #OldBusinessMembers.TrainingSvc_OldBusiness_Flag =1
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END) AS LocalCurrency_TrainingSvc_ResignTran_ItemAmount,

       SUM(CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Lab Testing','Metabolic Assessments')
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) and #OldBusinessMembers.AssessmentSvc_OldBusiness_Flag = 1
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate) AS AssessmentSvc_ResignTran_ItemAmount, 

       SUM(CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Lab Testing','Metabolic Assessments')
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) and #OldBusinessMembers.AssessmentSvc_OldBusiness_Flag = 1
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END ) AS LocalCurrency_AssessmentSvc_ResignTran_ItemAmount, 

       SUM(CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Devices','PT Nutritionals')
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) and #OldBusinessMembers.Products_OldBusiness_Flag = 1
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END * USDPlanExchangeRate.PlanExchangeRate) AS Products_ResignTran_ItemAmount,
			
       SUM(CASE WHEN ReportDimReportingHierarchy.DepartmentName in('Devices','PT Nutritionals')
                  and ((MMSR.TranTypeDescription = 'Charge' and MRP.ActivationDate Is Not Null)or (MMSR.TranTypeDescription <> 'Charge')) and #OldBusinessMembers.Products_OldBusiness_Flag = 1
                 THEN CASE WHEN ReportDimProduct.CorporateTransferFlag = 'Y' THEN MMSR.Quantity * ReportDimProduct.CorporateTransferMultiplier --11/14/2012 Corporate transfer
                           ELSE MMSR.ItemAmount END
            ELSE 0 
            END ) AS LocalCurrency_Products_ResignTran_ItemAmount					

  INTO #Results
  FROM vMMSRevenueReportSummary MMSR 
  JOIN vProduct P 
    ON P.ProductID = MMSR.ProductID
  JOIN vReportDimProduct ReportDimProduct 
    ON MMSR.ProductID = ReportDimProduct.MMSProductID
  JOIN vReportDimReportingHierarchy ReportDimReportingHierarchy 
    ON ReportDimProduct.DimReportingHierarchyKey = ReportDimReportingHierarchy.DimReportingHierarchyKey
  JOIN vMembership 
    ON vMembership.MembershipID = MMSR.MembershipID	
  JOIN vClub C 
    ON MMSR.PostingClubID = C.ClubID
  Join vValPTRCLArea Area
    On C.ValPTRCLAreaID = Area.ValPTRCLAreaID
  JOIN vPlanExchangeRate USDPlanExchangeRate
    ON ISNULL(MMSR.LocalCurrencyCode,'USD') = USDPlanExchangeRate.FromCurrencyCode
   AND 'USD' = USDPlanExchangeRate.ToCurrencyCode
   AND YEAR(MMSR.PostDateTime) = USDPlanExchangeRate.PlanYear
  LEFT JOIN #OldBusinessMembers
    ON #OldBusinessMembers.MemberID = MMSR.MemberID

  LEFT JOIN #MembershipRecurrentProduct MRP
    On MMSR.ProductID = MRP.ProductID
    AND MMSR.MembershipID = MRP.MembershipID
    AND MMSR.ValTranTypeID = 1  -- charge
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

  LEFT JOIN #ResultsForTotalNewBusinessMember #DefaultTotalNewBusinessMember
    On MMSR.MemberID = #DefaultTotalNewBusinessMember.MemberID
	AND MMSR.PostingClubID = #DefaultTotalNewBusinessMember.PostingClubID

 WHERE (MMSR.PostDateTime >= @StartDate AND MMSR.PostDateTime < @ENDDate)
        
  AND (ReportDimReportingHierarchy.DivisionName = 'Personal Training'
        And ((MMSR.ItemAmount <> 0 AND MMSR.EmployeeID <> -5)
             OR (MMSR.ItemAmount = 0 AND ReportDimProduct.CorporateTransferFlag = 'Y'))) 
  AND  ReportDimProduct.ReportNewBusinessOldBusinessFlag = 'Y'	 
  AND NOT (MMSR.TranTypeDescription ='Refund' AND (MMSTran2.PostDateTime IS NULL OR MMSTran2.PostDateTime < @StartDate)) -- RefundForPriorMonthTransactionFlag
 GROUP BY 
       Area.Description, 
       MMSR.PostingClubName, 
       MMSR.PostingClubid, 
	   C.ClubCode, 
       MMSR.MemberID



	 SELECT	 	 
	 MemberID,
     PostingRegionDescription AS PostingRegionDescription, 
     PostingClubName AS PostingClubName, 
     PostingClubid AS PostingClubid, 
	 PostingClubCode AS PostingClubCode,

	 ------- NewBusiness_ItemAmount,     ---- REP-161  Always return local currency values
	 LocalCurrency_NewBusiness_ItemAmount as NewBusiness_ItemAmount,
	 LocalCurrency_NewBusiness_ItemAmount,
	 CASE WHEN NewBusiness_ItemAmount <> 0 THEN 1 ELSE 0 END AS NewBusinessCount,	 
	 ------ OldBusiness_ItemAmount,      ---- REP-161
	 LocalCurrency_OldBusiness_ItemAmount as OldBusiness_ItemAmount,
	 LocalCurrency_OldBusiness_ItemAmount,
	 CASE WHEN OldBusiness_ItemAmount <> 0 THEN 1 ELSE 0 END AS OldBusinessCount,	 

	 ------- SNS_NewBusiness_ItemAmount,  ---- REP-161
	 LocalCurrency_SNS_NewBusiness_ItemAmount as SNS_NewBusiness_ItemAmount,
	 LocalCurrency_SNS_NewBusiness_ItemAmount,
	 CASE WHEN SNS_NewBusiness_ItemAmount <> 0 THEN 1 ELSE 0 END AS SNS_NewBusinessCount,	 
	 ------- SNS_OldBusiness_ItemAmount,   ---- REP-161
	 LocalCurrency_SNS_OldBusiness_ItemAmount as SNS_OldBusiness_ItemAmount,
	 LocalCurrency_SNS_OldBusiness_ItemAmount,
	 CASE WHEN SNS_OldBusiness_ItemAmount <> 0 THEN 1 ELSE 0 END AS SNS_OldBusinessCount,
	 
	 ------- TrainingSvc_NewTran_ItemAmount, ---- REP-161
	 LocalCurrency_TrainingSvc_NewTran_ItemAmount as TrainingSvc_NewTran_ItemAmount,
	 LocalCurrency_TrainingSvc_NewTran_ItemAmount,
	 CASE WHEN TrainingSvc_NewTran_ItemAmount <> 0 THEN 1 ELSE 0 END AS TrainingSvc_NewTran_Count,
	 ------- AssessmentSvc_NewTran_ItemAmount, ---- REP-161
	 LocalCurrency_AssessmentSvc_NewTran_ItemAmount as AssessmentSvc_NewTran_ItemAmount,
	 LocalCurrency_AssessmentSvc_NewTran_ItemAmount,
	 CASE WHEN AssessmentSvc_NewTran_ItemAmount <> 0 THEN 1 ELSE 0 END AS AssessmentSvc_NewTran_Count,
	 ------- Products_NewTran_ItemAmount,  ---- REP-161
	 LocalCurrency_Products_NewTran_ItemAmount as Products_NewTran_ItemAmount,
	 LocalCurrency_Products_NewTran_ItemAmount,
	 CASE WHEN Products_NewTran_ItemAmount <> 0 THEN 1 ELSE 0 END AS Products_NewTran_Count,

     ------- TrainingSvc_EFTTran_ItemAmount,   ---- REP-161
	 LocalCurrency_TrainingSvc_EFTTran_ItemAmount as TrainingSvc_EFTTran_ItemAmount,
	 LocalCurrency_TrainingSvc_EFTTran_ItemAmount,
	 (CASE WHEN TrainingSvc_EFTTran_ItemAmount <> 0 THEN 1 ELSE 0 END) AS TrainingSvc_EFTTran_Count,
	 ------- AssessmentSvc_EFTTran_ItemAmount,   ---- REP-161
	 LocalCurrency_AssessmentSvc_EFTTran_ItemAmount as AssessmentSvc_EFTTran_ItemAmount,
	 LocalCurrency_AssessmentSvc_EFTTran_ItemAmount,
	 CASE WHEN AssessmentSvc_EFTTran_ItemAmount <> 0 THEN 1 ELSE 0 END AS AssessmentSvc_EFTTran_Count,

	 ------- TrainingSvc_ResignTran_ItemAmount,   ---- REP-161
	 LocalCurrency_TrainingSvc_ResignTran_ItemAmount as TrainingSvc_ResignTran_ItemAmount,
	 LocalCurrency_TrainingSvc_ResignTran_ItemAmount,
	 (CASE WHEN TrainingSvc_ResignTran_ItemAmount <> 0 THEN 1 ELSE 0 END) AS TrainingSvc_ResignTran_Count,
	 ------- AssessmentSvc_ResignTran_ItemAmount,   ---- REP-161
	 LocalCurrency_AssessmentSvc_ResignTran_ItemAmount as AssessmentSvc_ResignTran_ItemAmount,
	 LocalCurrency_AssessmentSvc_ResignTran_ItemAmount,
     CASE WHEN AssessmentSvc_ResignTran_ItemAmount <> 0 THEN 1 ELSE 0 END AS AssessmentSvc_ResignTran_Count,
	 -------- Products_ResignTran_ItemAmount,   ---- REP-161
	 LocalCurrency_Products_ResignTran_ItemAmount as Products_ResignTran_ItemAmount,
	 LocalCurrency_Products_ResignTran_ItemAmount,		 
	 CASE WHEN Products_ResignTran_ItemAmount <> 0 THEN 1 ELSE 0 END AS Products_ResignTran_Count,
	 @ReportDate as ReportDate,
	 @ReportRunDateTime as ReportRunDateTime
	 
	 FROM #Results
	 WHERE ItemAmount <> 0
	 
 
 DROP TABLE #OldBusinessMembers
 DROP TABLE #OldBusinessMembers1
 DROP TABLE #ResultsForTotalNewBusinessMember
 DROP TABLE #Results
 DROP TABLE #MembershipRecurrentProduct

END



