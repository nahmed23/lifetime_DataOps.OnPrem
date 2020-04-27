



CREATE PROC [dbo].[procCognos_PrepareMMSGLRevenuePostingDetail]
(
                                @RowsProcessed int output, 
								@Description  varchar(80) output
)								
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

 IF 1=0 BEGIN
       SET FMTONLY OFF
     END

-- This procedure will prepare GL Revenue Posting Summary data for Revenue reports
/******* Amounts returned are in LocalCurrencyCode ******/

  DECLARE @Currentdayminus3 DATETIME
  DECLARE @FirstOfMonth DATETIME

  --Calculate Yesterday's Date
  SET @Currentdayminus3  =  DATEADD(dd, -3, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  --Calculate the first of the month for Yesterday's date
  SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@Currentdayminus3,112),1,6) + '01', 112)

SELECT distinct mt.MMSTranID, 
       mt.ClubID,
       mt.MembershipID, mt.MemberID, mt.DrawerActivityID,
       mt.TranVoidedID, mt.ReasonCodeID, mt.ValTranTypeID,
       mt.PostDateTime, mt.EmployeeID, mt.TranDate, mt.POSAmount,
       mt.TranAmount,
       mt.OriginalMMSTranID,
       mt.ValCurrencyCodeID,
       TI.TranItemID, TI.ItemAmount, TI.ItemSalesTax, TI.ItemDiscountAmount, TI.ProductID, TI.ClubID TranItemClubID,TI.Quantity ItemQuantity,
       Department.DepartmentID,
       Department.Description DeptDescription,
       P.Description ProductDescription,
       CASE WHEN BSP.ValGLGroupID is Null THEN ISNull(P.ValGLGroupID,0)
            ELSE BSP.ValGLGroupID END ValGLGroupID,
       CASE WHEN BSP.GLAccountNumber is Null THEN IsNull(P.GLAccountNumber,'')
            ELSE BSP.GLAccountNumber END GLAccountNumber,
       CASE WHEN BSP.GLSubAccountNumber is Null THEN IsNull(P.GLSubAccountNumber,'')
            ELSE BSP.GLSubAccountNumber END GLSubAccountNumber, 
       CASE WHEN BSP.GLOverRideClubID is Null THEN IsNull(P.GLOverRideClubID,0)
            ELSE BSP.GLOverRideClubID END GLOverRideClubID,
       CASE WHEN BSP.WorkdayOffering IS NULL THEN IsNull(P.WorkdayOffering,'')
            ELSE BSP.WorkdayOffering END WorkdayOffering,
       CASE WHEN BSP.WorkdayOverRideRegion IS NULL THEN IsNull(P.WorkdayOverRideRegion,'')
            ELSE BSP.WorkdayOverRideRegion END WorkdayOverRideRegion,
       CASE WHEN BSP.WorkdayCostCenter IS NULL THEN IsNull(P.WorkdayCostCenter,'')
            ELSE BSP.WorkdayCostCenter END WorkdayCostCenter,
       CASE WHEN BSP.WorkdayAccount IS NULL THEN IsNull(P.WorkdayAccount,'')
            ELSE BSP.WorkdayAccount END WorkdayAccount,
       CASE WHEN IsNull(P.DeferredRevenueFlag,0) = 1 THEN 'Y' ELSE 'N' END DeferredRevenueFlag,
       IsNull(P.RevenueCategory,'') as RevenueCategory,
       IsNull(P.SpendCategory,'') as SpendCategory,
       IsNull(P.PayComponent,'') as PayComponent
  INTO #MMSTran
  FROM vMMSTran mt WITH (NOLOCK)
  JOIN vMembership ms
    ON ms.MembershipID = mt.MembershipID
  JOIN vTranItem ti WITH (NOLOCK)
    ON ti.MMSTranID = mt.MMSTranID
  JOIN vProduct P
    ON TI.ProductID = P.ProductID
  JOIN vDepartment Department
    ON P.DepartmentID = Department.DepartmentID
  LEFT JOIN vBundleSubProduct  BSP
    ON TI.BundleProductID = BSP.BundleProductID
    AND TI.ProductID = BSP.SubProductID
 WHERE mt.PostDateTime >= @FirstOfMonth
   AND mt.PostDateTime < GETDATE()
   AND mt.TranVoidedID is null
   AND mt.ClubID <> 13
UNION
SELECT distinct mt.MMSTranID, 
       ms.ClubID,
       mt.MembershipID, mt.MemberID, mt.DrawerActivityID,
       mt.TranVoidedID, mt.ReasonCodeID, mt.ValTranTypeID,
       mt.PostDateTime, mt.EmployeeID, mt.TranDate, mt.POSAmount,
       mt.TranAmount,
       mt.OriginalMMSTranID,
       mt.ValCurrencyCodeID,
       TI.TranItemID, TI.ItemAmount, TI.ItemSalesTax, TI.ItemDiscountAmount, TI.ProductID, TI.ClubID TranItemClubID,TI.Quantity ItemQuantity,
       Department.DepartmentID,
       Department.Description DeptDescription,
       P.Description ProductDescription,
       CASE WHEN BSP.ValGLGroupID IS NULL THEN ISNull(P.ValGLGroupID,0)
            ELSE BSP.ValGLGroupID END ValGLGroupID,
       CASE WHEN BSP.GLAccountNumber IS NULL THEN IsNull(P.GLAccountNumber,'')
            ELSE BSP.GLAccountNumber END GLAccountNumber,
       CASE WHEN BSP.GLSubAccountNumber IS NULL  THEN IsNull(P.GLSubAccountNumber,'')
            ELSE BSP.GLSubAccountNumber END GLSubAccountNumber, 
       CASE WHEN BSP.GLOverRideClubID IS NULL THEN IsNull(P.GLOverRideClubID,0)
            ELSE BSP.GLOverRideClubID END GLOverRideclubID,
       CASE WHEN BSP.WorkdayOffering IS NULL THEN IsNull(P.WorkdayOffering,'')
            ELSE BSP.WorkdayOffering END WorkdayOffering,
       CASE WHEN BSP.WorkdayOverRideRegion IS NULL THEN IsNull(P.WorkdayOverRideRegion,'')
            ELSE BSP.WorkdayOverRideRegion END WorkdayOverRideRegion,
       CASE WHEN BSP.WorkdayCostCenter IS NULL THEN IsNull(P.WorkdayCostCenter,'')
            ELSE BSP.WorkdayCostCenter END WorkdayCostCenter,
       CASE WHEN BSP.WorkdayAccount IS NULL THEN IsNull(P.WorkdayAccount,'')
            ELSE BSP.WorkdayAccount END WorkdayAccount,
       CASE WHEN IsNull(P.DeferredRevenueFlag,0) = 1 THEN 'Y' ELSE 'N' END DeferredRevenueFlag,
       IsNull(P.RevenueCategory,'') as RevenueCategory,
       IsNull(P.SpendCategory,'') as SpendCategory,
       IsNull(P.PayComponent,'') as PayComponent
  FROM vMMSTran mt WITH (NOLOCK)
  JOIN vMembership ms
    ON ms.MembershipID = mt.MembershipID
  JOIN vTranItem TI
    ON mt.MMSTranID = TI.MMSTranID
  JOIN vProduct P
    ON TI.ProductID = P.ProductID
  JOIN vDepartment Department
    ON P.DepartmentID = Department.DepartmentID
  LEFT JOIN vBundleSubProduct  BSP
    ON TI.BundleProductID = BSP.BundleProductID
    AND TI.ProductID = BSP.SubProductID
 WHERE mt.PostDateTime >= @FirstOfMonth 
   AND mt.PostDateTime < GETDATE()
   AND mt.TranVoidedID is null
   AND mt.ClubID = 13

-- returns data on all unvoided automated refund transactions from closed drawers, 
-- posted in the prior month 
SELECT MMSTR.MMSTranRefundID,
       MMST.MMSTranID as RefundMMSTranID,
       MMST.ReasonCodeID as RefundReasonCodeID ,
       MS.ClubID as MembershipClubID 
  INTO #RefundTranIDs
  FROM vMMSTranRefund MMSTR
  JOIN #MMSTran MMST 
    ON MMST.MMSTranID = MMSTR.MMSTranID
  JOIN vMembership MS 
    ON MS.MembershipID = MMST.MembershipID
  JOIN vDrawerActivity DA 
    ON DA.DrawerActivityID = MMST.DrawerActivityID 
 WHERE MMST.TranVoidedID is null
   AND DA.ValDrawerStatusID = 3 -- closed drawers only
   AND MMST.PostDateTime >= @FirstOfMonth 
   AND MMST.PostDateTime < GETDATE()

SELECT distinct mt.MMSTranID, 
       mt.ClubID,
       RTID.MembershipClubID,
       RTID.RefundMMSTranID,
       RTID.RefundReasonCodeID
  INTO #MMSTran2
  FROM vMMSTran mt WITH (NOLOCK)
  JOIN vMMSTranRefundMMSTran MMSTRT 
    ON MMSTRT.OriginalMMSTranID = mt.MMSTranID
  JOIN #RefundTranIDs RTID
    ON MMSTRT.MMSTranRefundID = RTID.MMSTranRefundID
  JOIN #MMSTran MMSTNA 
    ON RTID.RefundMMSTranID = MMSTNA.MMSTranID
 WHERE mt.TranVoidedID is null

-- This query returns original MMSTran transaction data and current membership club data gathered in #RefundTranIDs
-- to determine the club where transaction will be assigned
SELECT #MMSTran2.RefundMMSTranID,
       CASE WHEN #MMSTran2.RefundReasonCodeID = 108 or #MMSTran2.ClubID in (13) THEN #MMSTran2.MembershipClubID 
            ELSE #MMSTran2.ClubID END AS PostingMMSClubID 
  INTO #ReportRefunds
  FROM #MMSTran2
  JOIN vClub MembershipClub 
    ON #MMSTran2.MembershipClubID = MembershipClub.ClubID
 GROUP BY #MMSTran2.RefundMMSTranID,
          CASE WHEN #MMSTran2.RefundReasonCodeID = 108 or #MMSTran2.ClubID in (13) THEN #MMSTran2.MembershipClubID 
               ELSE #MMSTran2.ClubID END

CREATE TABLE #RevenueGLPosting(
       ItemAmount DECIMAL(12,2),--MONEY,
       DepartmentID INT,
       DeptDescription VARCHAR(50),
       ProductDescription VARCHAR(50),
       MembershipClubName VARCHAR(50),
       DrawerActivityID INT,
       PostDateTime DATETIME,
       TranDate DATETIME,
       ValTranTypeID INT,
       MemberID INT,
       ItemSalesTax DECIMAL(12,2),--MONEY,
       EmployeeID INT,
       MemberFirstName VARCHAR(50),
       MemberLastName VARCHAR(50),
       TranItemId INT,
       TranMemberJoinDate DATETIME,
       MembershipActivationDate DATETIME,
       MembershipID INT,
       ValGLGroupID INT,
       GLAccountNumber VARCHAR(10),
       GLSubAccountNumber VARCHAR(10),
       GLOverRideClubID INT,
       ProductID INT,
       GLGroupIDDescription VARCHAR(50),
       MMSTranClubID INT,
       Posting_MMSClubID INT,
       EmployeeFirstName VARCHAR(50),
       EmployeeLastName VARCHAR(50),
       TransactionDescrption VARCHAR(50),
       TranTypeDescription VARCHAR(50),
       Reconciliation_Sales DECIMAL(12,2),--MONEY,
       Reconciliation_Adjustment DECIMAL(12,2),--MONEY,
       Reconciliation_Refund DECIMAL(12,2),--MONEY,
       Reconciliation_DuesAssessCharge DECIMAL(12,2),--MONEY,
       Reconciliation_AllOtherCharges DECIMAL(12,2),--MONEY,
       Reconciliation_ReportMonthYear VARCHAR(20),
       Reconciliation_Posting_Sub_Account VARCHAR(20),
       Reconciliation_ReportHeader_TranType VARCHAR(50),
       Reconciliation_Adj_GLAccountNumber VARCHAR(10),
       SortValGroupID INT,
       Adj_ValGroupID_Desc VARCHAR(200),
       ItemDiscountAmount DECIMAL(12,2),--Money,
       DiscountGLAccount VARCHAR(5),
       ItemQuantity INT,
       ReasonCodeID INT,
       WorkdayAccount VARCHAR(10),
       WorkdayCostCenter VARCHAR(6),
       WorkdayOffering VARCHAR(10),
       DeferredRevenueFlag CHAR(1),
       WorkdayOverRideRegion VARCHAR(4),
       Reconciliation_Adj_WorkdayAccount VARCHAR(10),
       Reconciliation_PostingWorkdayCostCenter VARCHAR(6),
       Reconciliation_PostingWorkdayOffering VARCHAR(10),
       RevenueCategory VARCHAR(7),
       SpendCategory VARCHAR(7),
       PayComponent VARCHAR(50),
       DiscountWorkdayAccount VARCHAR(10))

INSERT INTO #RevenueGLPosting
SELECT MMST.ItemAmount, MMST.DepartmentID, MMST.DeptDescription, MMST.ProductDescription, 
       C2.ClubName MembershipClubname, MMST.DrawerActivityID, MMST.PostDateTime, 
       MMST.TranDate, MMST.ValTranTypeID, MMST.MemberID, 
       MMST.ItemSalesTax, MMST.EmployeeID, M.FirstName MemberFirstname, 
       M.LastName MemberLastname, MMST.TranItemID, M.JoinDate TranMemberJoinDate, 
       MS.ActivationDate MembershipActivationDate,
       MMST.MembershipID, MMST.ValGLGroupID, MMST.GLAccountNumber, 
       MMST.GLSubAccountNumber, MMST.GLOverRideClubID, MMST.ProductID, 
       VGLG.Description GLGroupIDDescription, 
       MMST.ClubID MMSTranClubID,
       C1.ClubID Posting_MMSClubID,
       E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, 
       MMST4.Description TransactionDescription, VTT.Description TranTypeDescription,
       CASE MMST.Valtrantypeid WHEN 3 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Sales,
       CASE MMST.Valtrantypeid WHEN 4 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Adjustment,
       CASE MMST.Valtrantypeid WHEN 5 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Refund,
       CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_DuesAssessCharge,
       CASE WHEN (MMST.Draweractivityid <= 0 OR MMST.Employeeid >= 0) AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_AllOtherCharges,
       DATENAME(MM, MMST.PostDateTime) + ' ' + DATENAME(YY, MMST.PostDateTime) AS Reconciliation_ReportMonthYear,
       CASE WHEN MMST.GLOverRideClubID = 0
                 THEN CAST(C1.GLClubID AS VARCHAR(10)) + '-' + MMST.GLSubAccountNumber
            ELSE CAST(MMST.GLOverRideClubID AS VARCHAR(10)) + '-' + MMST.GLSubAccountNumber END AS Reconciliation_Posting_Sub_Account,
       CASE VTT.Description WHEN 'Automated Refund' THEN 'Refund' ELSE VTT.Description END AS Reconciliation_ReportHeader_TranType,
       '' AS Reconciliation_Adj_GLAccountNumber,

	     CASE WHEN MMST.ProductID = 1497
		      AND ((MMST.Employeeid = -6 AND  MMST.Valtrantypeid = 1)   ------ Internet Sales
		            OR
		            (MMST.Employeeid < 0 AND  MMST.Valtrantypeid <> 1)  ----- Not Any other automated charge
					 OR 
					  MMST.Employeeid > 0)  
                 THEN 2
              WHEN MMST.ValGLGroupID = 12
                 THEN 998
              WHEN MMST.ValGLGroupID = 13
                 THEN 999
              WHEN MMST.ValGLGroupID = 1 

	              AND ((MMST.Employeeid = -6 AND  MMST.Valtrantypeid = 1)   ------ Internet Sales
		            OR
		            (MMST.Employeeid < 0 AND  MMST.Valtrantypeid <> 1)  ----- Not Any other automated charge
					 OR 
					  MMST.Employeeid > 0)  
                 THEN 2
              ELSE MMST.ValGLGroupID 
			  END AS SortValGroupID,
       '' AS Adj_ValGroupID_Desc,
       MMST.ItemDiscountAmount,
       GLA.DiscountGLAccount,
       MMST.ItemQuantity,
       MMST.ReasonCodeID,     
       MMST.WorkdayAccount,
       MMST.WorkdayCostCenter,
       MMST.WorkdayOffering,
       MMST.DeferredRevenueFlag,
       MMST.WorkdayOverRideRegion,
       '' AS Reconciliation_Adj_WorkdayAccount,
       MMST.WorkdayCostCenter Reconciliation_PostingWorkdayCostCenter,
       MMST.WorkdayOffering Reconciliation_PostingWorkdayOffering,
       MMST.RevenueCategory,
       MMST.SpendCategory,
       MMST.PayComponent,
       WorkdayGLA.DiscountGLAccount AS DiscountWorkdayAccount
  FROM #MMSTran MMST
  LEFT JOIN vMMSTranRefund MMSTR 
       ON MMSTR.MMSTranID = MMST.MMSTranID
  JOIN dbo.vClub C1
       ON C1.ClubID = MMST.ClubID
  JOIN dbo.vValRegion VR
       ON C1.ValRegionID = VR.ValRegionID
  JOIN vMembership MS
       ON MS.MembershipID = MMST.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValTranType VTT
       ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValGLGroup VGLG
       ON MMST.ValGLGroupID = VGLG.ValGLGroupID
  JOIN dbo.vEmployee E
       ON MMST.EmployeeID = E.EmployeeID
  JOIN dbo.vReasonCode MMST4
       ON MMST4.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vDrawerActivity DA 
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  LEFT JOIN dbo.vGLAccount GLA
       ON MMST.GLAccountNumber = GLA.RevenueGLAccountNumber
  LEFT JOIN dbo.vGLAccount WorkdayGLA
       ON MMST.WorkdayAccount = WorkdayGLA.RevenueGLAccountNumber
 WHERE VTT.ValTranTypeID IN (1,3,4) 
   AND DA.ValDrawerStatusID = 3 
   AND C1.ClubID not in(9999) 
   AND MMSTR.MMSTranRefundID is NULL -- no automated refunds are returned

UNION

SELECT MMST.ItemAmount,MMST.DepartmentID, MMST.DeptDescription, MMST.ProductDescription, 
       C2.ClubName MembershipClubname, MMST.DrawerActivityID, MMST.PostDateTime, 
       MMST.TranDate, MMST.ValTranTypeID, MMST.MemberID, 
       MMST.ItemSalesTax, MMST.EmployeeID, M.FirstName MemberFirstname, 
       M.LastName MemberLastname, MMST.TranItemID, M.JoinDate TranMemberJoinDate, 
       MS.ActivationDate MembershipActivationDate,
       MMST.MembershipID, MMST.ValGLGroupID, MMST.GLAccountNumber, 
       MMST.GLSubAccountNumber, MMST.GLOverRideClubID, MMST.ProductID, 
       VGLG.Description GLGroupIDDescription,
       MMST.ClubID MMSTranClubID,
       CASE WHEN TranItemClub.ClubID IS NULL THEN C1.ClubID
            ELSE TranItemClub.ClubID END AS Posting_MMSClubID,
       E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, 
       MMST4.Description TransactionDescription, VTT.Description TranTypeDescription,
       CASE MMST.Valtrantypeid WHEN 3 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Sales,
       CASE MMST.Valtrantypeid WHEN 4 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Adjustment,
       CASE MMST.Valtrantypeid WHEN 5 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Refund,
       CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_DuesAssessCharge,
       CASE WHEN (MMST.Draweractivityid <= 0 OR MMST.Employeeid >= 0) AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_AllOtherCharges,
       DATENAME(MM, MMST.PostDateTime) + ' ' + DATENAME(YY, MMST.PostDateTime) AS Reconciliation_ReportMonthYear,
       CASE WHEN MMST.GLOverRideClubID = 0
                 THEN CAST(CASE WHEN TranItemClub.ClubID IS NULL THEN C1.GLClubID
                                ELSE TranItemClub.GLClubID 
                           END AS VARCHAR(10)) + '-' + MMST.GLSubAccountNumber
                 ELSE CAST(MMST.GLOverRideClubID AS VARCHAR(10)) + '-' + MMST.GLSubAccountNumber
       END AS Reconciliation_Posting_Sub_Account,
       CASE VTT.Description WHEN 'Automated Refund' THEN 'Refund' ELSE VTT.Description END AS Reconciliation_ReportHeader_TranType,
       '' AS Reconciliation_Adj_GLAccountNumber,

	   CASE WHEN MMST.ProductID = 1497
		      AND ((MMST.Employeeid = -6 AND  MMST.Valtrantypeid = 1)   ------ Internet Sales
		            OR
		            (MMST.Employeeid < 0 AND  MMST.Valtrantypeid <> 1)  ----- Not Any other automated charge
					 OR 
					  MMST.Employeeid > 0)  
                 THEN 2
            WHEN MMST.ValGLGroupID = 12
                 THEN 998
            WHEN MMST.ValGLGroupID = 13
                 THEN 999
            WHEN MMST.ValGLGroupID = 1 

				 AND ((MMST.Employeeid = -6 AND  MMST.Valtrantypeid = 1)   ------ Internet Sales
		            OR
		            (MMST.Employeeid < 0 AND  MMST.Valtrantypeid <> 1)  ----- Not Any other automated charge
					 OR 
					  MMST.Employeeid > 0)  
                 THEN 2
            ELSE MMST.ValGLGroupID END AS SortValGroupID,
       '' AS Adj_ValGroupID_Desc,
       MMST.ItemDiscountAmount,
       GLA.DiscountGLAccount,
       MMST.ItemQuantity,
       MMST.ReasonCodeID,
       MMST.WorkdayAccount,
       MMST.WorkdayCostCenter,
       MMST.WorkdayOffering,
       MMST.DeferredRevenueFlag,
       MMST.WorkdayOverRideRegion,
       '' AS Reconciliation_Adj_WorkdayAccount,
       MMST.WorkdayCostCenter Reconciliation_PostingWorkdayCostCenter,
       MMST.WorkdayOffering Reconciliation_PostingWorkdayOffering,
       MMST.RevenueCategory,
       MMST.SpendCategory,
       MMST.PayComponent,
       WorkdayGLA.DiscountGLAccount AS DiscountWorkdayAccount
  FROM #MMSTran MMST
  LEFT JOIN vMMSTranRefund MMSTR 
       ON MMSTR.MMSTranID = MMST.MMSTranID
  JOIN dbo.vClub C1
       ON C1.ClubID = MMST.ClubID
  JOIN dbo.vValRegion VR
       ON C1.ValRegionID = VR.ValRegionID
  LEFT JOIN dbo.vClub TranItemClub
       ON MMST.TranItemClubID = TranItemClub.ClubID
  JOIN vMembership MS
       ON MS.MembershipID = MMST.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValTranType VTT
       ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValGLGroup VGLG
       ON MMST.ValGLGroupID = VGLG.ValGLGroupID
  JOIN dbo.vEmployee E
       ON MMST.EmployeeID = E.EmployeeID
  JOIN dbo.vReasonCode MMST4
       ON MMST4.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vDrawerActivity DA 
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  LEFT JOIN dbo.vGLAccount GLA
       ON  MMST.GLAccountNumber = GLA.RevenueGLAccountNumber
  LEFT JOIN dbo.vGLAccount WorkdayGLA
       ON MMST.WorkdayAccount = WorkdayGLA.RevenueGLAccountNumber
 WHERE VTT.ValTranTypeID IN (1,3,4) 
   AND DA.ValDrawerStatusID = 3 
   AND C1.ClubID = 9999 
   AND MMSTR.MMSTranRefundID is NULL -- no automated refunds are returned

UNION

-- Automated Refunds 
SELECT MMST.ItemAmount,MMST.DepartmentID,MMST.DeptDescription, MMST.ProductDescription, 
       C2.ClubName MembershipClubname, MMST.DrawerActivityID, MMST.PostDateTime, 
       MMST.TranDate, MMST.ValTranTypeID, MMST.MemberID, 
       MMST.ItemSalesTax, MMST.EmployeeID, M.FirstName MemberFirstname, 
       M.LastName MemberLastname, MMST.TranItemID, M.JoinDate TranMemberJoinDate, 
       MS.ActivationDate MembershipActivationDate,
       MMST.MembershipID, MMST.ValGLGroupID, GLA.RefundGLAccountNumber AS GLAccountNumber, 
       MMST.GLSubAccountNumber, MMST.GLOverRideClubID, MMST.ProductID, 
       VGLG.Description GLGroupIDDescription, 
       MMST.ClubID MMSTranClubID,
       C3.ClubID AS Posting_MMSClubid, 
       E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, 
       MMST4.Description TransactionDescription,
       'Automated Refund' AS TranTypeDescription,
       CASE MMST.Valtrantypeid WHEN 3 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Sales,
       CASE MMST.Valtrantypeid WHEN 4 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Adjustment,
       CASE MMST.Valtrantypeid WHEN 5 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Refund,
       CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_DuesAssessCharge,
       CASE WHEN (MMST.Draweractivityid <= 0 OR MMST.Employeeid >= 0) AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_AllOtherCharges,
       DATENAME(MM, MMST.PostDateTime) + ' ' + DATENAME(YY, MMST.PostDateTime) AS Reconciliation_ReportMonthYear,
       CASE MMST.GLOverRideClubID
            WHEN 0
                 THEN CAST(C3.GLClubID AS VARCHAR(10)) + '-' + MMST.GLSubAccountNumber -- 5/12/2010 MLL Modified
                 ELSE CAST(MMST.GLOverRideClubID AS VARCHAR(10)) + '-' + MMST.GLSubAccountNumber
       END AS Reconciliation_Posting_Sub_Account,
       'Refund' AS Reconciliation_ReportHeader_TranType,
       '' AS Reconciliation_Adj_GLAccountNumber,

	   CASE WHEN MMST.ProductID = 1497
		      AND ((MMST.Employeeid = -6 AND  MMST.Valtrantypeid = 1)   ------ Internet Sales
		            OR
		            (MMST.Employeeid < 0 AND  MMST.Valtrantypeid <> 1)  ----- Not Any other automated charge
					 OR 
					  MMST.Employeeid > 0)  
                 THEN 2
            WHEN MMST.ValGLGroupID = 12
                 THEN 998
            WHEN MMST.ValGLGroupID = 13
                 THEN 999
            WHEN MMST.ValGLGroupID = 1 

			     AND ((MMST.Employeeid = -6 AND  MMST.Valtrantypeid = 1)   ------ Internet Sales
		            OR
		            (MMST.Employeeid < 0 AND  MMST.Valtrantypeid <> 1)  ----- Not Any other automated charge
					 OR 
					  MMST.Employeeid > 0)  
                 THEN 2
            ELSE MMST.ValGLGroupID END AS SortValGroupID,
       '' AS Adj_ValGroupID_Desc,
       MMST.ItemDiscountAmount,
       GLA.DiscountGLAccount,
       MMST.ItemQuantity,
       MMST.ReasonCodeID,
       WorkdayGLA.RefundGLAccountNumber WorkdayAccount,
       MMST.WorkdayCostCenter,
       MMST.WorkdayOffering,
       MMST.DeferredRevenueFlag,
       MMST.WorkdayOverRideRegion,
       '' AS Reconciliation_Adj_WorkdayAccount,
       MMST.WorkdayCostCenter Reconciliation_PostingWorkdayCostCenter,
       MMST.WorkdayOffering Reconciliation_PostingWorkdayOffering,
       MMST.RevenueCategory,
       MMST.SpendCategory,
       MMST.PayComponent,
       WorkdayGLA.DiscountGLAccount AS DiscountWorkdayAccount
  FROM #MMSTran MMST
  JOIN #ReportRefunds #RR
       ON #RR.RefundMMSTranID = MMST.MMSTranID
  LEFT JOIN vGLAccount GLA
       ON MMST.GLAccountNumber = GLA.RevenueGLAccountNumber
  LEFT JOIN vGLAccount WorkdayGLA
       ON MMST.WorkdayAccount = WorkdayGLA.RevenueGLAccountNumber
  JOIN vMembership MS
       ON MS.MembershipID = MMST.MembershipID
  JOIN dbo.vClub MembershipClub
       ON MS.ClubID = MembershipClub.ClubID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vClub C3
       ON C3.ClubID = #RR.PostingMMSClubID
  JOIN dbo.vValTranType VTT
       ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValGLGroup VGLG
       ON MMST.ValGLGroupID = VGLG.ValGLGroupID
  JOIN dbo.vEmployee E
       ON MMST.EmployeeID = E.EmployeeID
  JOIN dbo.vReasonCode MMST4
       ON MMST4.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vDrawerActivity DA 
       ON MMST.DrawerActivityID = DA.DrawerActivityID
 WHERE VTT.Description IN ('Adjustment', 'Charge', 'Refund', 'Sale') 
   AND DA.ValDrawerStatusID = 3 

UPDATE #RevenueGLPosting
   SET Adj_ValGroupID_Desc = CASE WHEN ReasonCodeID = 254 THEN 'Next Month Dues'
                                  WHEN SortValGroupID = 2 AND TranTypeDescription = 'Automated Refund' THEN 'Membership Dues - Refund'
                                  WHEN SortValGroupID = 2 AND TranTypeDescription = 'Adjustment' THEN 'Current Month Dues - Adjustment'
                                  WHEN SortValGroupID = 2 AND TranTypeDescription IN ('Sale', 'Charge') THEN 'Current Month Dues'
                                  WHEN SortValGroupID IN (998, 999) AND TranTypeDescription = 'Automated Refund' THEN ProductDescription + ' - Refund'
                                  WHEN ProductID IN (3504,4280) AND TranTypeDescription = 'Adjustment' THEN ProductDescription + ' - Adjustment'
                                  WHEN SortValGroupID IN (998, 999)  THEN ProductDescription
                                  WHEN TranTypeDescription = 'Automated Refund' THEN GLGroupIDDescription + ' - Refund'
                                  ELSE GLGroupIDDescription END,
       Reconciliation_Adj_GLAccountNumber = CASE WHEN ReasonCodeID = 254 THEN '2300'
	                                             WHEN SortValGroupID = 2 AND TranTypeDescription IN ('Sale', 'Charge') THEN '4003'
                                                 WHEN SortValGroupID = 2 AND ReasonCodeID = 219 AND TranTypeDescription = 'Adjustment' THEN '4004'
                                                 WHEN SortValGroupID = 2 AND ReasonCodeID <> 219 AND TranTypeDescription = 'Adjustment' THEN '4008'
                                                 WHEN ProductID IN (3504, 4280) AND TranTypeDescription = 'Adjustment' THEN '4008'
                                                 ELSE GLAccountNumber END,
       Reconciliation_Adj_WorkdayAccount = CASE WHEN ReasonCodeID = 254 THEN '214005'
	                                            WHEN SortValGroupID = 2 AND TranTypeDescription IN ('Sale', 'Charge') THEN '411005'
                                                WHEN SortValGroupID = 2 AND ReasonCodeID = 219 AND TranTypeDescription = 'Adjustment' THEN '411005'
                                                WHEN SortValGroupID = 2 AND ReasonCodeID <> 219 AND TranTypeDescription = 'Adjustment' THEN '411005'
                                                WHEN ProductID IN (3504, 4280) AND TranTypeDescription = 'Adjustment' THEN '411005'
                                                ELSE WorkdayAccount END,
       RevenueCategory = CASE WHEN ReasonCodeID = 254 THEN 'RC50140'
	                                            WHEN SortValGroupID = 2 AND TranTypeDescription IN ('Sale', 'Charge') THEN 'RC50023'
                                                WHEN SortValGroupID = 2 AND ReasonCodeID = 219 AND TranTypeDescription = 'Adjustment' THEN 'RC50018'
                                                WHEN SortValGroupID = 2 AND ReasonCodeID <> 219 AND TranTypeDescription = 'Adjustment' THEN 'RC50026'
                                                WHEN ProductID IN (3504, 4280) AND TranTypeDescription = 'Adjustment' THEN 'RC50026'
                                                WHEN Convert(INT,WorkdayAccount)< 400000 THEN ''
                                                ELSE RevenueCategory END,
       SpendCategory = CASE WHEN Convert(INT,WorkdayAccount)< 400000 THEN ''
                                                ELSE SpendCategory END,
       PayComponent = CASE WHEN Convert(INT,WorkdayAccount)< 400000 THEN ''
                                                ELSE PayComponent END,
	   Reconciliation_Posting_Sub_Account = CASE WHEN ReasonCodeID = 254 THEN CAST(Left(Reconciliation_Posting_Sub_Account,3) AS VARCHAR(10)) + '-' + '000-000'
                                                ELSE Reconciliation_Posting_Sub_Account END

 DELETE MMSRevenueGLPostingSummary
  WHERE PostDateTime >= @FirstOfMonth
    AND PostDateTime < GETDATE()  --get rid of current months data

INSERT INTO MMSRevenueGLPostingSummary
      (MMSRegion,ClubName,MMSClubCode,LocalCurrencyItemAmount,USDItemAmount,
       LocalCurrencyItemDiscountAmount,USDItemDiscountAmount,LocalCurrencyGLPostingAmount,
       USDGLPostingAmount,DepartmentID,DeptDescription,
       ProductDescription,MembershipClubName,DrawerActivityID,
       PostDateTime,TranDate,ValTranTypeID,MemberID,LocalCurrencyItemSalesTax,
       USDItemSalesTax,EmployeeID,MemberFirstName,MemberLastName,
       TranItemId,TranMemberJoinDate,MembershipActivationDate,
       MembershipID,ValGLGroupID,GLAccountNumber,
       GLSubAccountNumber,GLOverRideClubID,ProductID,GLGroupIDDescription,
       GLTaxID,Posting_GLClubID,Posting_RegionDescription,Posting_ClubName,
       MMSTranClubID,Posting_MMSClubID,CurrencyCode,MonthlyAverageExchangeRate,
       EmployeeFirstName,EmployeeLastName,TransactionDescrption,
       TranTypeDescription,Reconciliation_Adj_ValGroupID_Desc,
       LocalCurrencyReconciliation_Sales,USDReconciliation_Sales,
       LocalCurrencyReconciliation_Adjustment,USDReconciliation_Adjustment,
       LocalCurrencyReconciliation_Refund,USDReconciliation_Refund,
       LocalCurrencyReconciliation_DuesAssessCharge,USDReconciliation_DuesAssessCharge,
       LocalCurrencyReconciliation_AllOtherCharges,USDReconciliation_AllOtherCharges,
       Reconciliation_ReportMonthYear,Reconciliation_Posting_Sub_Account,
       Reconciliation_ReportHeader_TranType,
       Reconciliation_ReportLineGrouping,
       Reconciliation_Adj_GLAccountNumber,PostingInstruction,ItemQuantity,
       WorkdayAccount,
       WorkdayCostCenter,
       WorkdayOffering,
       WorkdayRegion,
       WorkdayOverRideRegion,
       DeferredRevenueFlag,
       Reconciliation_Adj_WorkdayAccount,
       Reconciliation_PostingWorkdayRegion,
       Reconciliation_PostingWorkdayCostCenter,
       Reconciliation_PostingWorkdayOffering,
       Reconciliation_WorkdayReportLineGrouping,
       RevenueCategory,
       SpendCategory,
       PayComponent)
SELECT VR.Description MMSRegion,
       C.ClubName,
       C.ClubCode MMSClubCode,
       ItemAmount LocalCurrencyItemAmount,
       ItemAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDItemAmount,
       ISNULL(ItemDiscountAmount,0) LocalCurrencyItemDiscountAmount,
       ISNULL(ItemDiscountAmount,0) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDItemDiscountAmount,
       (ISNULL(ItemAmount,0) + ISNULL(ItemDiscountAmount,0)) LocalCurrencyGLPostingAmount,
       (ISNULL(ItemAmount,0) + ISNULL(ItemDiscountAmount,0)) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDGLPostingAmount,
       DepartmentID,
       DeptDescription,
       ProductDescription,
       MembershipClubName,
       DrawerActivityID,
       PostDateTime,
       TranDate,
       ValTranTypeID,
       MemberID,
       ItemSalesTax LocalCurrencyItemSalesTax,
       ItemSalesTax * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDItemSalesTax,
       EmployeeID,
       MemberFirstName,
       MemberLastName,
       TranItemId,
       TranMemberJoinDate,
       MembershipActivationDate,
       MembershipID,
       ValGLGroupID,
       GLAccountNumber,
       GLSubAccountNumber,
       GLOverRideClubID,
       ProductID,
       GLGroupIDDescription,
       C.GLTaxID,
       C.GLClubID Posting_GLClubID,
       VR.Description Posting_RegionDescription,
       C.ClubName Posting_ClubName,
       MMSTranClubID,
       Posting_MMSClubID,
       VCC.CurrencyCode,
       USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate,
       EmployeeFirstName,
       EmployeeLastName,
       TransactionDescrption,
       TranTypeDescription,
       Adj_ValGroupID_Desc as Reconciliation_Adj_ValGroupID_Desc,
       Reconciliation_Sales LocalCurrencyReconciliation_Sales,
       Reconciliation_Sales * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDReconciliation_Sales,
       Reconciliation_Adjustment LocalCurrencyReconciliation_Adjustment,
       Reconciliation_Adjustment * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDReconciliation_Adjustment,
       Reconciliation_Refund LocalCurrencyReconciliation_Refund,
       Reconciliation_Refund * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDReconciliation_Refund,
       Reconciliation_DuesAssessCharge LocalCurrencyReconciliation_DuesAssessCharge,
       Reconciliation_DuesAssessCharge * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDReconciliation_DuesAssessCharge,
       Reconciliation_AllOtherCharges LocalCurrencyReconciliation_AllOtherCharges,
       Reconciliation_AllOtherCharges * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDReconciliation_AllOtherCharges,
       Reconciliation_ReportMonthYear,
       Reconciliation_Posting_Sub_Account,
       Reconciliation_ReportHeader_TranType,
       Adj_ValGroupID_Desc + Reconciliation_Adj_GLAccountNumber + Reconciliation_Posting_Sub_Account Reconciliation_ReportLineGrouping,
       Reconciliation_Adj_GLAccountNumber,
       'Positive = Credit Entry and Negative = Debit Entry' AS PostingInstruction,
       ItemQuantity,
       WorkdayAccount,
       WorkdayCostCenter,
       WorkdayOffering,
       C.WorkdayRegion,--#RevenueGLPosting.WorkdayRegion,
       WorkdayOverRideRegion,
       DeferredRevenueFlag,
       Reconciliation_Adj_WorkdayAccount,
       CASE WHEN ISNULL(#RevenueGLPosting.WorkdayOverRideRegion,0) <> 0 THEN #RevenueGLPosting.WorkdayOverRideRegion
            ELSE C.WorkdayRegion END Reconciliation_PostingWorkdayRegion,
       Reconciliation_PostingWorkdayCostCenter,
       Reconciliation_PostingWorkdayOffering,
       Adj_ValGroupID_Desc + Reconciliation_Adj_WorkdayAccount+Reconciliation_PostingWorkdayCostCenter+Reconciliation_PostingWorkdayOffering Reconciliation_WorkdayReportLineGrouping,
       RevenueCategory,
       SpendCategory,
       PayComponent
  FROM #RevenueGLPosting
  JOIN vClub C ON #RevenueGLPosting.Posting_MMSClubID = C.ClubID
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN vValRegion VR ON C.ValRegionID = VR.ValRegionID
  JOIN vMonthlyAverageExchangeRate USDMonthlyAverageExchangeRate
    ON VCC.CurrencyCode = USDMonthlyAverageExchangeRate.FromCurrencyCode
   AND 'USD' = USDMonthlyAverageExchangeRate.ToCurrencyCode
   AND @FirstOfMonth = USDMonthlyAverageExchangeRate.FirstOfMonthDate

UNION

SELECT VR.Description MMSRegion,
       C.ClubName,
       C.ClubCode MMSClubCode,
       ItemAmount LocalCurrencyItemAmount,
       ItemAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDItemAmount,
       ISNULL(ItemDiscountAmount,0) LocalCurrencyItemDiscountAmount,
       ISNULL(ItemDiscountAmount,0) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDItemDiscountAmount,
       ISNULL(ItemDiscountAmount,0) LocalCurrencyGLPostingAmount,
       ISNULL(ItemDiscountAmount,0) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDGLPostingAmount,
       DepartmentID,
       DeptDescription,
       ProductDescription,
       MembershipClubName,
       DrawerActivityID,
       PostDateTime,
       TranDate,
       ValTranTypeID,
       MemberID,
       0 LocalCurrencyItemSalesTax,
       0 USDItemSalesTax,
       EmployeeID,
       MemberFirstName,
       MemberLastName,
       TranItemId,
       TranMemberJoinDate,
       MembershipActivationDate,
       MembershipID,
       ValGLGroupID,
       DiscountGLAccount as GLAccountNumber,
       GLSubAccountNumber,
       GLOverRideClubID,
       ProductID,
       GLGroupIDDescription,
       C.GLTaxID,
       C.GLClubID Posting_GLClubID,
       VR.Description Posting_RegionDescription,
       C.ClubName Posting_ClubName,
       MMSTranClubID,
       Posting_MMSClubID,
       VCC.CurrencyCode,
       USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate,
       EmployeeFirstName,
       EmployeeLastName,
       TransactionDescrption,
       TranTypeDescription,
       Case WHEN Adj_ValGroupID_Desc LIKE '%- Refund%' THEN REPLACE(Adj_ValGroupID_Desc, '- Refund', '- Discount Refund')
            ELSE Adj_ValGroupID_Desc + ' - Discount' END Reconciliation_Adj_ValGroupID_Desc,
       Reconciliation_Sales LocalCurrencyReconciliation_Sales,
       Reconciliation_Sales * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDReconciliation_Sales,
       Reconciliation_Adjustment LocalCurrencyReconciliation_Adjustment,
       Reconciliation_Adjustment * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDReconciliation_Adjustment,
       Reconciliation_Refund LocalCurrencyReconciliation_Refund,
       Reconciliation_Refund * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDReconciliation_Refund,
       Reconciliation_DuesAssessCharge LocalCurrencyReconciliation_DuesAssessCharge,
       Reconciliation_DuesAssessCharge * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDReconciliation_DuesAssessCharge,
       Reconciliation_AllOtherCharges LocalCurrencyReconciliation_AllOtherCharges,
       Reconciliation_AllOtherCharges * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDReconciliation_AllOtherCharges,
       Reconciliation_ReportMonthYear,
       Reconciliation_Posting_Sub_Account,
       Reconciliation_ReportHeader_TranType,
       CASE WHEN Adj_ValGroupID_Desc LIKE '%- Refund%' THEN REPLACE(Adj_ValGroupID_Desc, '- Refund', '- Discount Refund') + COALESCE(DiscountGLAccount, 'NULL') + Reconciliation_Posting_Sub_Account 
            ELSE Adj_ValGroupID_Desc + '- Discount' + COALESCE(DiscountGLAccount, 'NULL') + Reconciliation_Posting_Sub_Account End Reconciliation_ReportLineGrouping,
       DiscountGLAccount as Reconciliation_Adj_GLAccountNumber,
       'Positive = Debit Entry and Negative = Credit Entry' AS PostingInstruction,
       ItemQuantity,
       DiscountWorkdayAccount as WorkdayAccount,
       WorkdayCostCenter,
       WorkdayOffering,
       C.WorkdayRegion,--#RevenueGLPosting.WorkdayRegion,
       WorkdayOverRideRegion,
       DeferredRevenueFlag,
       DiscountWorkdayAccount as Reconciliation_Adj_WorkdayAccount,
       CASE WHEN ISNULL(#RevenueGLPosting.WorkdayOverRideRegion,0) <> 0 THEN #RevenueGLPosting.WorkdayOverRideRegion
            ELSE C.WorkdayRegion END Reconciliation_PostingWorkdayRegion,
       Reconciliation_PostingWorkdayCostCenter,
       Reconciliation_PostingWorkdayOffering,
       CASE WHEN Adj_ValGroupID_Desc LIKE '%- Refund%' THEN REPLACE(Adj_ValGroupID_Desc, '- Refund', '- Discount Refund') + Reconciliation_Adj_WorkdayAccount+Reconciliation_PostingWorkdayCostCenter+Reconciliation_PostingWorkdayOffering
            ELSE Adj_ValGroupID_Desc + '- Discount' + Reconciliation_Adj_WorkdayAccount+Reconciliation_PostingWorkdayCostCenter+Reconciliation_PostingWorkdayOffering END Reconciliation_WorkdayReportLineGrouping,
       RevenueCategory,
       SpendCategory,
       PayComponent     
  FROM #RevenueGLPosting
  JOIN vClub C ON #RevenueGLPosting.Posting_MMSClubID = C.ClubID
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN vValRegion VR ON C.ValRegionID = VR.ValRegionID
  JOIN vMonthlyAverageExchangeRate USDMonthlyAverageExchangeRate
    ON VCC.CurrencyCode = USDMonthlyAverageExchangeRate.FromCurrencyCode
   AND 'USD' = USDMonthlyAverageExchangeRate.ToCurrencyCode
   AND @FirstOfMonth = USDMonthlyAverageExchangeRate.FirstofMonthDate
 WHERE ItemDiscountAmount <> 0
   AND ItemDiscountAmount Is Not Null
Order by Posting_GLClubID, Adj_ValGroupID_Desc

DROP TABLE #RefundTranIDs 
DROP TABLE #ReportRefunds 
DROP TABLE #RevenueGLPosting
drop table #MMSTran
drop table #MMSTran2

SELECT @RowsProcessed = 1
SELECT @Description = 'MMS GL Posting Summary Built ' 

END



