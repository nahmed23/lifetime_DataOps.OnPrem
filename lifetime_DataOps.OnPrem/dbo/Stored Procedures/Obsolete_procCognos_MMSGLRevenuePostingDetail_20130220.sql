
CREATE PROC [dbo].[Obsolete_procCognos_MMSGLRevenuePostingDetail_20130220](
   @StartFourDigitYearDashTwoDigitMonth CHAR(7), 
   @MMSDepartmentList VARCHAR(4000), 
   @MMSClubIDList VARCHAR(4000),
   @GLAccountNumberList VARCHAR(8000))
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @StartDate DATETIME,
        @EndDate DATETIME,
        @ReportRunDateTime VARCHAR(21)

SET @StartDate = Convert(Datetime,SUBSTRING(@StartFourDigitYearDashTwoDigitMonth,6,2)+'-01-'+SUBSTRING(@StartFourDigitYearDashTwoDigitMonth,1,4))
SET @EndDate = DATEADD(MM,1,@StartDate)
SET @ReportRunDateTime = Replace(Substring(convert(varchar, GetDate(), 100),1,6)+', '+Substring(convert(varchar, GetDate(), 100),8,10)+' '+Substring(convert(varchar,GetDate(), 100),18,2),'  ',' ')

CREATE TABLE #tmpList(StringField VARCHAR(50))
EXEC procParseStringList @MMSDepartmentList

SELECT D.DepartmentID, D.Description
  INTO #DepartmentIDList
  FROM #tmpList
  JOIN vDepartment D
    ON #tmpList.StringField = D.Description

TRUNCATE TABLE #tmpList
EXEC procParseStringList @MMSClubIDList

SELECT #tmpList.StringField MMSClubID
  INTO #MMSClubIDList
  FROM #tmpList

TRUNCATE TABLE #tmpList
EXEC procParseStringList @GLAccountNumberList

SELECT #tmpList.StringField GLAccountNumber
  INTO #GLAccountNumberList
  FROM #tmpList

SELECT ms.MembershipID,
       ms.ClubID,
       ms.ActivationDate
  INTO #Membership
  FROM vMembership ms WITH (NOLOCK)

CREATE INDEX IX_MembershipID ON #Membership(MembershipID)
CREATE INDEX IX_ClubID ON #Membership(ClubID)

SELECT distinct mt.MMSTranID, 
       mt.ClubID,
       mt.MembershipID, mt.MemberID, mt.DrawerActivityID,
       mt.TranVoidedID, mt.ReasonCodeID, mt.ValTranTypeID, mt.DomainName, mt.ReceiptNumber, 
       mt.ReceiptComment, mt.PostDateTime, mt.EmployeeID, mt.TranDate, mt.POSAmount,
       mt.TranAmount, mt.OriginalDrawerActivityID, mt.ChangeRendered, mt.UTCPostDateTime, 
       mt.PostDateTimeZone, mt.OriginalMMSTranID, mt.TranEditedFlag,
       mt.TranEditedEmployeeID, mt.TranEditedDateTime, mt.UTCTranEditedDateTime, 
       mt.TranEditedDateTimeZone, mt.ReverseTranFlag, mt.ComputerName, mt.IPAddress,
       mt.ValCurrencyCodeID,mt.CorporatePartnerID,mt.ConvertedAmount,mt.ConvertedValCurrencyCodeID,
       TI.TranItemID, TI.ItemAmount, TI.ItemSalesTax, TI.ItemDiscountAmount, TI.ProductID, TI.ClubID TranItemClubID,TI.Quantity ItemQuantity,
       #DepartmentIDList.Description DeptDescription,
       P.Description ProductDescription, P.ValGLGroupID, P.GLAccountNumber, P.GLSubAccountNumber, P.GLOverRideClubID
  INTO #MMSTran
  FROM vMMSTran mt WITH (NOLOCK)
  JOIN #Membership ms
    ON ms.MembershipID = mt.MembershipID
  JOIN vTranItem ti WITH (NOLOCK)
    ON ti.MMSTranID = mt.MMSTranID
  JOIN vProduct P
    ON TI.ProductID = P.ProductID
  JOIN #DepartmentIDList
    ON P.DepartmentID = #DepartmentIDList.DepartmentID
 WHERE mt.PostDateTime >= @StartDate
   AND mt.PostDateTime < @EndDate
   AND mt.TranVoidedID is null
   AND mt.ClubID <> 13
UNION
SELECT distinct mt.MMSTranID, 
       ms.ClubID,
       mt.MembershipID, mt.MemberID, mt.DrawerActivityID,
       mt.TranVoidedID, mt.ReasonCodeID, mt.ValTranTypeID, mt.DomainName, mt.ReceiptNumber, 
       mt.ReceiptComment, mt.PostDateTime, mt.EmployeeID, mt.TranDate, mt.POSAmount,
       mt.TranAmount, mt.OriginalDrawerActivityID, mt.ChangeRendered, mt.UTCPostDateTime, 
       mt.PostDateTimeZone, mt.OriginalMMSTranID, mt.TranEditedFlag,
       mt.TranEditedEmployeeID, mt.TranEditedDateTime, mt.UTCTranEditedDateTime, 
       mt.TranEditedDateTimeZone, mt.ReverseTranFlag, mt.ComputerName, mt.IPAddress,
       mt.ValCurrencyCodeID,mt.CorporatePartnerID,mt.ConvertedAmount,mt.ConvertedValCurrencyCodeID,
       TI.TranItemID, TI.ItemAmount, TI.ItemSalesTax, TI.ItemDiscountAmount, TI.ProductID, TI.ClubID TranItemClubID,TI.Quantity ItemQuantity,
       #DepartmentIDList.Description DeptDescription,
       P.Description ProductDescription, P.ValGLGroupID, P.GLAccountNumber, P.GLSubAccountNumber, P.GLOverRideClubID
  FROM vMMSTran mt WITH (NOLOCK)
  JOIN #Membership ms
    ON ms.MembershipID = mt.MembershipID
  JOIN vTranItem TI
    ON mt.MMSTranID = TI.MMSTranID
  JOIN vProduct P
    ON TI.ProductID = P.ProductID
  JOIN #DepartmentIDList
    ON P.DepartmentID = #DepartmentIDList.DepartmentID
  JOIN #MMSClubIDList
    ON ms.ClubID = #MMSClubIDList.MMSClubID
 WHERE mt.PostDateTime >= @StartDate 
   AND mt.PostDateTime < @EndDate
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
  JOIN #Membership MS 
    ON MS.MembershipID = MMST.MembershipID
  JOIN vDrawerActivity DA 
    ON DA.DrawerActivityID = MMST.DrawerActivityID 
 WHERE MMST.TranVoidedID is null
   AND DA.ValDrawerStatusID = 3 -- closed drawers only
   AND MMST.PostDateTime >= @StartDate 
   AND MMST.PostDateTime < @EndDate


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
       ItemQuantity INT)

INSERT INTO #RevenueGLPosting

SELECT MMST.ItemAmount, MMST.DeptDescription, MMST.ProductDescription, 
       C2.ClubName MembershipClubname, MMST.DrawerActivityID, MMST.PostDateTime, 
       MMST.TranDate, MMST.ValTranTypeID, MMST.MemberID, 
       MMST.ItemSalesTax, MMST.EmployeeID, M.FirstName MemberFirstname, 
       M.LastName MemberLastname, MMST.TranItemID, M.JoinDate TranMemberJoinDate, 
       MS.ActivationDate MembershipActivationDate,
       MMST.MembershipID, MMST.ValGLGroupID, MMST.GLAccountNumber, 
       MMST.GLSubAccountNumber, MMST.GLOverRideClubID, MMST.ProductID, 
       VGLG.Description GLGroupIDDescription, 
       C1.ClubID Posting_MMSClubID,
       E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, 
       MMST4.Description TransactionDescription, VTT.Description TranTypeDescription,
       CASE MMST.Valtrantypeid WHEN 3 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Sales,
       CASE MMST.Valtrantypeid WHEN 4 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Adjustment,
       CASE MMST.Valtrantypeid WHEN 5 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Refund,
       CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_DuesAssessCharge,
       CASE WHEN (MMST.Draweractivityid <= 0 OR MMST.Employeeid >= 0) AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_AllOtherCharges,
       DATENAME(MM, MMST.PostDateTime) + ' ' + DATENAME(YY, MMST.PostDateTime) AS Reconciliation_ReportMonthYear,
       CASE MMST.GLOverRideClubID
            WHEN 0
                 THEN CAST(C1.GLClubID AS VARCHAR(10)) + '-' + MMST.GLSubAccountNumber
                 ELSE CAST(MMST.GLOverRideClubID AS VARCHAR(10)) + '-' + MMST.GLSubAccountNumber
       END AS Reconciliation_Posting_Sub_Account,
       CASE VTT.Description WHEN 'Automated Refund' THEN 'Refund' ELSE VTT.Description END AS Reconciliation_ReportHeader_TranType,
       '' AS Reconciliation_Adj_GLAccountNumber,
       CASE WHEN MMST.ProductID = 1497 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END = 0
                 THEN 2
            WHEN MMST.ValGLGroupID = 12
                 THEN 998
            WHEN MMST.ValGLGroupID = 13
                 THEN 999
            WHEN MMST.ValGLGroupID = 1 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END = 0
                 THEN 2
            ELSE MMST.ValGLGroupID END AS SortValGroupID,
       '' AS Adj_ValGroupID_Desc,
       MMST.ItemDiscountAmount,
       GLA.DiscountGLAccount,
       MMST.ItemQuantity
  FROM #MMSTran MMST
  LEFT JOIN vMMSTranRefund MMSTR 
       ON MMSTR.MMSTranID = MMST.MMSTranID
  JOIN dbo.vClub C1
       ON C1.ClubID = MMST.ClubID
  JOIN dbo.vValRegion VR
       ON C1.ValRegionID = VR.ValRegionID
  JOIN #Membership MS
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
 WHERE VTT.ValTranTypeID IN (1,3,4) 
   AND DA.ValDrawerStatusID = 3 
   AND C1.ClubID not in(9999) 
   AND MMSTR.MMSTranRefundID is NULL -- no automated refunds are returned
   AND MMST.ClubID IN (SELECT MMSClubID FROM #MMSClubIDList)

UNION

SELECT MMST.ItemAmount, MMST.DeptDescription, MMST.ProductDescription, 
       C2.ClubName MembershipClubname, MMST.DrawerActivityID, MMST.PostDateTime, 
       MMST.TranDate, MMST.ValTranTypeID, MMST.MemberID, 
       MMST.ItemSalesTax, MMST.EmployeeID, M.FirstName MemberFirstname, 
       M.LastName MemberLastname, MMST.TranItemID, M.JoinDate TranMemberJoinDate, 
       MS.ActivationDate MembershipActivationDate,
       MMST.MembershipID, MMST.ValGLGroupID, MMST.GLAccountNumber, 
       MMST.GLSubAccountNumber, MMST.GLOverRideClubID, MMST.ProductID, 
       VGLG.Description GLGroupIDDescription,
       CASE WHEN TranItemClub.ClubID IS NULL THEN C1.ClubID
            ELSE TranItemClub.ClubID 
       END AS Posting_MMSClubID,
       E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, 
       MMST4.Description TransactionDescription, VTT.Description TranTypeDescription,
       CASE MMST.Valtrantypeid WHEN 3 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Sales,
       CASE MMST.Valtrantypeid WHEN 4 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Adjustment,
       CASE MMST.Valtrantypeid WHEN 5 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_Refund,
       CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_DuesAssessCharge,
       CASE WHEN (MMST.Draweractivityid <= 0 OR MMST.Employeeid >= 0) AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END AS Reconciliation_AllOtherCharges,
       DATENAME(MM, MMST.PostDateTime) + ' ' + DATENAME(YY, MMST.PostDateTime) AS Reconciliation_ReportMonthYear,
       CASE MMST.GLOverRideClubID
            WHEN 0
                 THEN CAST(CASE WHEN TranItemClub.ClubID IS NULL THEN C1.GLClubID
                                ELSE TranItemClub.GLClubID 
                           END AS VARCHAR(10)) + '-' + MMST.GLSubAccountNumber
                 ELSE CAST(MMST.GLOverRideClubID AS VARCHAR(10)) + '-' + MMST.GLSubAccountNumber
       END AS Reconciliation_Posting_Sub_Account,
       CASE VTT.Description WHEN 'Automated Refund' THEN 'Refund' ELSE VTT.Description END AS Reconciliation_ReportHeader_TranType,
       '' AS Reconciliation_Adj_GLAccountNumber,
       CASE WHEN MMST.ProductID = 1497 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END = 0
                 THEN 2
            WHEN MMST.ValGLGroupID = 12
                 THEN 998
            WHEN MMST.ValGLGroupID = 13
                 THEN 999
            WHEN MMST.ValGLGroupID = 1 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END = 0
                 THEN 2
            ELSE MMST.ValGLGroupID END AS SortValGroupID,
       '' AS Adj_ValGroupID_Desc,
       MMST.ItemDiscountAmount,
       GLA.DiscountGLAccount,
       MMST.ItemQuantity
  FROM #MMSTran MMST
  LEFT JOIN vMMSTranRefund MMSTR 
       ON MMSTR.MMSTranID = MMST.MMSTranID
  JOIN dbo.vClub C1
       ON C1.ClubID = MMST.ClubID
  JOIN dbo.vValRegion VR
       ON C1.ValRegionID = VR.ValRegionID
  LEFT JOIN dbo.vClub TranItemClub
       ON MMST.TranItemClubID = TranItemClub.ClubID
  JOIN #Membership MS
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
 WHERE MMST.TranItemClubID IN (SELECT MMSClubID FROM #MMSClubIDList)
   AND VTT.ValTranTypeID IN (1,3,4) 
   AND DA.ValDrawerStatusID = 3 
   AND C1.ClubID = 9999 
   AND MMSTR.MMSTranRefundID is NULL -- no automated refunds are returned

UNION

-- Automated Refunds 
SELECT MMST.ItemAmount, MMST.DeptDescription, MMST.ProductDescription, 
       C2.ClubName MembershipClubname, MMST.DrawerActivityID, MMST.PostDateTime, 
       MMST.TranDate, MMST.ValTranTypeID, MMST.MemberID, 
       MMST.ItemSalesTax, MMST.EmployeeID, M.FirstName MemberFirstname, 
       M.LastName MemberLastname, MMST.TranItemID, M.JoinDate TranMemberJoinDate, 
       MS.ActivationDate MembershipActivationDate,
       MMST.MembershipID, MMST.ValGLGroupID, GLA.RefundGLAccountNumber AS GLAccountNumber, 
       MMST.GLSubAccountNumber, MMST.GLOverRideClubID, MMST.ProductID, 
       VGLG.Description GLGroupIDDescription, 
       #RR.PostingMMSClubID AS Posting_MMSClubid, 
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
                 THEN CAST(MembershipClub.GLClubID AS VARCHAR(10)) + '-' + MMST.GLSubAccountNumber -- 5/12/2010 MLL Modified
                 ELSE CAST(MMST.GLOverRideClubID AS VARCHAR(10)) + '-' + MMST.GLSubAccountNumber
       END AS Reconciliation_Posting_Sub_Account,
       'Refund' AS Reconciliation_ReportHeader_TranType,
       '' AS Reconciliation_Adj_GLAccountNumber,
       CASE WHEN MMST.ProductID = 1497 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END = 0
                 THEN 2
            WHEN MMST.ValGLGroupID = 12
                 THEN 998
            WHEN MMST.ValGLGroupID = 13
                 THEN 999
            WHEN MMST.ValGLGroupID = 1 AND CASE WHEN MMST.Draweractivityid > 0 AND MMST.Employeeid < 0 AND MMST.Valtrantypeid = 1 THEN MMST.Itemamount ELSE 0 END = 0
                 THEN 2
            ELSE MMST.ValGLGroupID END AS SortValGroupID,
       '' AS Adj_ValGroupID_Desc,
       MMST.ItemDiscountAmount,
       GLA.DiscountGLAccount,
       MMST.ItemQuantity
  FROM #MMSTran MMST
  JOIN #ReportRefunds #RR
       ON #RR.RefundMMSTranID = MMST.MMSTranID
  JOIN dbo.vClub MembershipClub
       ON #RR.PostingMMSClubID = MembershipClub.ClubID
  LEFT JOIN vGLAccount GLA
       ON MMST.GLAccountNumber = GLA.RevenueGLAccountNumber
  JOIN #Membership MS
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
 WHERE VTT.Description IN ('Adjustment', 'Charge', 'Refund', 'Sale') 
   AND DA.ValDrawerStatusID = 3 
   AND CASE WHEN #RR.PostingMMSClubID = 9999 THEN MMST.TranItemClubID ELSE #RR.PostingMMSClubID END IN (SELECT MMSClubID FROM #MMSClubIDList)


UPDATE #RevenueGLPosting
   SET Adj_ValGroupID_Desc = CASE WHEN SortValGroupID = 2 AND TranTypeDescription = 'Automated Refund' THEN 'Membership Dues - Refund'
                                  WHEN SortValGroupID = 2 AND TranTypeDescription = 'Adjustment' THEN 'Current Month Dues - Adjustment'
                                  WHEN SortValGroupID = 2 AND TranTypeDescription IN ('Sale', 'Charge') THEN 'Current Month Dues'
                                  WHEN SortValGroupID IN (998, 999) AND TranTypeDescription = 'Automated Refund' THEN ProductDescription + ' - Refund'
                                  WHEN ProductID IN (3504,4280) AND TranTypeDescription = 'Adjustment' THEN ProductDescription + ' - Adjustment'
                                  WHEN SortValGroupID IN (998, 999)  THEN ProductDescription
                                  WHEN TranTypeDescription = 'Automated Refund' THEN GLGroupIDDescription + ' - Refund'
                                  ELSE GLGroupIDDescription END,
       Reconciliation_Adj_GLAccountNumber = CASE WHEN SortValGroupID = 2 AND TranTypeDescription = 'Adjustment' THEN '4008'
                                                 WHEN SortValGroupID = 2 AND TranTypeDescription IN ('Sale', 'Charge') THEN '4003'
                                                 WHEN ProductID IN (3504, 4280) AND TranTypeDescription = 'Adjustment' THEN '4008'
                                                 ELSE GLAccountNumber END

SELECT VR.Description MMSRegion,
       C.ClubName,
       C.ClubCode MMSClubCode,
       ItemAmount LocalCurrencyItemAmount,
       ItemAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDItemAmount,
       ISNULL(ItemDiscountAmount,0) LocalCurrencyItemDiscountAmount,
       ISNULL(ItemDiscountAmount,0) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDItemDiscountAmount,
       (ISNULL(ItemAmount,0) + ISNULL(ItemDiscountAmount,0)) LocalCurrencyGLPostingAmount,
       (ISNULL(ItemAmount,0) + ISNULL(ItemDiscountAmount,0)) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDGLPostingAmount,
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
       Adj_ValGroupID_Desc + Reconciliation_Adj_GLAccountNumber + GLSubAccountNumber Reconciliation_ReportLineGrouping,
       Reconciliation_Adj_GLAccountNumber,
       'Positive = Credit Entry and Negative = Debit Entry' AS PostingInstruction,
       ItemQuantity
  INTO #Results
  FROM #RevenueGLPosting
  JOIN vClub C ON #RevenueGLPosting.Posting_MMSClubID = C.ClubID
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN vValRegion VR ON C.ValRegionID = VR.ValRegionID
  JOIN vMonthlyAverageExchangeRate USDMonthlyAverageExchangeRate
    ON VCC.CurrencyCode = USDMonthlyAverageExchangeRate.FromCurrencyCode
   AND 'USD' = USDMonthlyAverageExchangeRate.ToCurrencyCode
   AND @StartDate = USDMonthlyAverageExchangeRate.FirstOfMonthDate

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
       CASE WHEN Adj_ValGroupID_Desc LIKE '%- Refund%' THEN REPLACE(Adj_ValGroupID_Desc, '- Refund', '- Discount Refund') + COALESCE(DiscountGLAccount, 'NULL') + GLSubAccountNumber  
            ELSE Adj_ValGroupID_Desc + '- Discount' + COALESCE(DiscountGLAccount, 'NULL') + GLSubAccountNumber End Reconciliation_ReportLineGrouping,
       DiscountGLAccount as Reconciliation_Adj_GLAccountNumber,
       'Positive = Debit Entry and Negative = Credit Entry' AS PostingInstruction,
       ItemQuantity
  FROM #RevenueGLPosting
  JOIN vClub C ON #RevenueGLPosting.Posting_MMSClubID = C.ClubID
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN vValRegion VR ON C.ValRegionID = VR.ValRegionID
  JOIN vMonthlyAverageExchangeRate USDMonthlyAverageExchangeRate
    ON VCC.CurrencyCode = USDMonthlyAverageExchangeRate.FromCurrencyCode
   AND 'USD' = USDMonthlyAverageExchangeRate.ToCurrencyCode
   AND @StartDate = USDMonthlyAverageExchangeRate.FirstofMonthDate
 WHERE ItemDiscountAmount <> 0
   AND ItemDiscountAmount Is Not Null
Order by Posting_GLClubID, Adj_ValGroupID_Desc

SELECT MMSRegion,
       ClubName,
       MMSClubCode,
       Cast(LocalCurrencyItemAmount as Decimal(16,6)) LocalCurrencyItemAmount,
       Cast(USDItemAmount as Decimal(16,6)) USDItemAmount,
       Cast(LocalCurrencyItemDiscountAmount as Decimal(16,6)) LocalCurrencyItemDiscountAmount,
       Cast(USDItemDiscountAmount as Decimal(16,6)) USDItemDiscountAmount,
       Cast(LocalCurrencyGLPostingAmount as Decimal(16,6)) LocalCurrencyGLPostingAmount,
       Cast(USDGLPostingAmount as Decimal(16,6)) USDGLPostingAmount,
       DeptDescription,
       ProductDescription,
       MembershipClubName,
       DrawerActivityID,
       PostDateTime,
       TranDate,
       ValTranTypeID,
       MemberID,
       Cast(LocalCurrencyItemSalesTax as Decimal(16,6)) LocalCurrencyItemSalesTax,
       Cast(USDItemSalesTax as Decimal(16,6)) USDItemSalesTax,
       EmployeeID,
       MemberFirstName,
       MemberLastName,
       TranItemId,
       TranMemberJoinDate,
       MembershipActivationDate,
       MembershipID,
       ValGLGroupID,
       #Results.GLAccountNumber,
       GLSubAccountNumber,
       GLOverRideClubID,
       ProductID,
       GLGroupIDDescription,
       GLTaxID,
       Posting_GLClubID,
       Posting_RegionDescription,
       Posting_ClubName,
       Posting_MMSClubID,
       CurrencyCode,
       MonthlyAverageExchangeRate,
       EmployeeFirstName,
       EmployeeLastName,
       TransactionDescrption,
       TranTypeDescription,
       Reconciliation_Adj_ValGroupID_Desc,
       Cast(LocalCurrencyReconciliation_Sales as Decimal(16,6)) LocalCurrencyReconciliation_Sales,
       Cast(USDReconciliation_Sales as Decimal(16,6)) USDReconciliation_Sales,
       Cast(LocalCurrencyReconciliation_Adjustment as Decimal(16,6)) LocalCurrencyReconciliation_Adjustment,
       Cast(USDReconciliation_Adjustment as Decimal(16,6)) USDReconciliation_Adjustment,
       Cast(LocalCurrencyReconciliation_Refund as Decimal(16,6)) LocalCurrencyReconciliation_Refund,
       Cast(USDReconciliation_Refund as Decimal(16,6)) USDReconciliation_Refund,
       Cast(LocalCurrencyReconciliation_DuesAssessCharge as Decimal(16,6)) LocalCurrencyReconciliation_DuesAssessCharge,
       Cast(USDReconciliation_DuesAssessCharge as Decimal(16,6)) USDReconciliation_DuesAssessCharge,
       Cast(LocalCurrencyReconciliation_AllOtherCharges as Decimal(16,6)) LocalCurrencyReconciliation_AllOtherCharges,
       Cast(USDReconciliation_AllOtherCharges as Decimal(16,6)) USDReconciliation_AllOtherCharges,
       Reconciliation_ReportMonthYear,
       Reconciliation_Posting_Sub_Account,
       Reconciliation_ReportHeader_TranType,
       Reconciliation_ReportLineGrouping,
       Reconciliation_Adj_GLAccountNumber,
       PostingInstruction,
       @ReportRunDateTime ReportRunDateTime,
       @StartFourDigitYearDashTwoDigitMonth HeaderYearMonth,
       Cast('' as Varchar(80)) HeaderEmptyResult,
       ItemQuantity
  FROM #Results
  JOIN #GLAccountNumberList
    ON #Results.Reconciliation_Adj_GLAccountNumber = #GLAccountNumberList.GLAccountNumber
 WHERE (SELECT COUNT(*) FROM #Results) > 0
UNION ALL
SELECT Cast(NULL AS Varchar(50)) MMSRegion,
       Cast(NULL AS Varchar(50)) ClubName,
       Cast(NULL AS Varchar(3)) MMSClubCode,
       Cast(NULL AS Decimal(16,6)) LocalCurrencyItemAmount,
       Cast(NULL AS Decimal(16,6)) USDItemAmount,
       Cast(NULL AS Decimal(16,6)) LocalCurrencyItemDiscountAmount,
       Cast(NULL AS Decimal(16,6)) USDItemDiscountAmount,
       Cast(NULL AS Decimal(16,6)) LocalCurrencyGLPostingAmount,
       Cast(NULL AS Decimal(16,6)) USDGLPostingAmount,
       Cast(NULL AS Varchar(50)) DeptDescription,
       Cast(NULL AS Varchar(50)) ProductDescription,
       Cast(NULL AS Varchar(50)) MembershipClubName,
       Cast(NULL AS INT) DrawerActivityID,
       Cast(NULL AS DATETIME) PostDateTime,
       Cast(NULL AS DATETIME) TranDate,
       Cast(NULL AS INT) ValTranTypeID,
       Cast(NULL AS INT) MemberID,
       Cast(NULL AS Decimal(16,6)) LocalCurrencyItemSalesTax,
       Cast(NULL AS Decimal(16,6)) USDItemSalesTax,
       Cast(NULL AS INT) EmployeeID,
       Cast(NULL AS Varchar(50)) MemberFirstName,
       Cast(NULL AS Varchar(50)) MemberLastName,
       Cast(NULL AS INT) TranItemId,
       Cast(NULL AS DATETIME) TranMemberJoinDate,
       Cast(NULL AS DATETIME) MembershipActivationDate,
       Cast(NULL AS INT) MembershipID,
       Cast(NULL AS INT) ValGLGroupID,
       Cast(NULL AS Varchar(10)) GLAccountNumber,
       Cast(NULL AS Varchar(10)) GLSubAccountNumber,
       Cast(NULL AS INT) GLOverRideClubID,
       Cast(NULL AS INT) ProductID,
       Cast(NULL AS Varchar(50)) GLGroupIDDescription,
       Cast(NULL AS INT) GLTaxID,
       Cast(NULL AS INT) Posting_GLClubID,
       Cast(NULL AS Varchar(50)) Posting_RegionDescription,
       Cast(NULL AS Varchar(50)) Posting_ClubName,
       Cast(NULL AS INT) Posting_MMSClubID,
       Cast(NULL AS Varchar(3)) CurrencyCode,
       Cast(NULL AS Decimal(14,4)) MonthlyAverageExchangeRate,
       Cast(NULL AS Varchar(50)) EmployeeFirstName,
       Cast(NULL AS Varchar(50)) EmployeeLastName,
       Cast(NULL AS Varchar(50)) TransactionDescrption,
       Cast(NULL AS Varchar(50)) TranTypeDescription,
       Cast(NULL AS Varchar(8000)) Reconciliation_Adj_ValGroupID_Desc,
       Cast(NULL AS Varchar(50)) LocalCurrencyReconciliation_Sales,
       Cast(NULL AS Varchar(50)) USDReconciliation_Sales,
       Cast(NULL AS Varchar(50)) LocalCurrencyReconciliation_Adjustment,
       Cast(NULL AS Varchar(50)) USDReconciliation_Adjustment,
       Cast(NULL AS Varchar(50)) LocalCurrencyReconciliation_Refund,
       Cast(NULL AS Varchar(50)) USDReconciliation_Refund,
       Cast(NULL AS Varchar(50)) LocalCurrencyReconciliation_DuesAssessCharge,
       Cast(NULL AS Varchar(50)) USDReconciliation_DuesAssessCharge,
       Cast(NULL AS Varchar(50)) LocalCurrencyReconciliation_AllOtherCharges,
       Cast(NULL AS Varchar(50)) USDReconciliation_AllOtherCharges,
       Cast(NULL AS Varchar(20)) Reconciliation_ReportMonthYear,
       Cast(NULL AS Varchar(20)) Reconciliation_Posting_Sub_Account,
       Cast(NULL AS Varchar(50)) Reconciliation_ReportHeader_TranType,
       Cast(NULL AS Varchar(8000)) Reconciliation_ReportLineGrouping,
       Cast(NULL AS Varchar(10)) Reconciliation_Adj_GLAccountNumber,
       Cast(NULL AS Varchar(102)) PostingInstruction,
       @ReportRunDateTime ReportRunDateTime,
       @StartFourDigitYearDashTwoDigitMonth HeaderYearMonth,
       'There are no transactions available for the selected parameters.  Please re-try.' HeaderEmptyResult,
       CAST(NULL as INT) ItemQuantity
 WHERE (SELECT COUNT(*) FROM #Results) = 0
 
DROP TABLE #tmpList
DROP TABLE #DepartmentIDList
DROP TABLE #MMSClubIDList
DROP TABLE #GLAccountNumberList
DROP TABLE #RefundTranIDs 
DROP TABLE #ReportRefunds 
DROP TABLE #RevenueGLPosting
drop table #membership
drop table #MMSTran
drop table #MMSTran2

END

