


CREATE PROC [dbo].[mmsFitnessProgram_Revenue] (
  @StartPostDate SMALLDATETIME,
  @EndPostDate SMALLDATETIME,
  @ClubList VARCHAR(8000)		-- 3/13/08 GRB
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- =============================================
-- Object:			dbo.mmsFitnessProgram_Revenue
-- Author:			Greg Burdick
-- Create date: 	3/6/2008
-- Description:		Returns a set of tran records for the Revenuerpt;
--					This proc adds 1 minute to the endpostdate to 
--					include records within the last minute;  it expects a 'PM'
--					to be included with the time portion, i.e., 11:59 PM;
-- 
-- Modified Date:	4/4/2011 BSD: Including ProductID 5234 QC6963
--                  1/31/2011 BSD: Removed 10/19 change for new business rule for ClubID = 9999
--                  12/29/2010 BSD: Added 'Mixed Combat Arts' to the list of departments and filtering out 'LT Endurance'
--                  10/19/2010 BSD: Updated filter to act the same with ClubID=9999 as ClubID=13
--					07/15/2010 MLL:  Add Discount information
--                  3/13/08 GRB: re-added club parm and related code to enable PT Payroll Worksheet functionality to work;
--					3/6/08 GRB: cloned msRevenuerpt_Revenue and added code to omit item amounts = 0;
-- 
-- EXEC dbo.mmsFitnessProgram_Revenue '2/1/08', '2/29/08 11:59 PM', 'all'
--
-- =============================================

  DECLARE @AdjustedEndPostDate AS SMALLDATETIME
  DECLARE @StartDate AS DATETIME
  DECLARE @EndDate AS DATETIME

--	inverted values assigned to @StartDate and @EndDate to comply with conditional logic below, determining which data source to use;
  SET @StartDate = DATEADD(m,-4,CONVERT(DATETIME,CONVERT(VARCHAR(11),GETDATE()))) --Four Months Old 
  SET @EndDate = CONVERT(DATETIME,CONVERT(VARCHAR(11),GETDATE())) --Today (the first moment, ie: 3/4/08 00:00:00 )


  SET @AdjustedEndPostDate = DATEADD(mi, 1, @EndPostDate)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

--	start 3/13/08 added new code
  CREATE TABLE #tmpList (StringField VARCHAR(50))
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
--	end 3/18/08 added new code

--	Use vMMSRevenueReportSummary if date range within the last four (4) months;
  IF @StartPostDate >= @StartDate AND
     @EndPostDate <= @EndDate		-- The summary table is only re-built once each night, so any query involving “today’s” data will need to use the MMSTran table
  BEGIN
          SELECT 
--				'MMSRevenueReportSummary' AS DataSource, @StartPostDate AS StartPostDate, 
--				@EndPostDate AS EndPostDate, @AdjustedEndPostDate AS AdjustedEndPostDate, 
--				@StartDate AS StartDate, @EndDate AS EndDate, 
				PostingClubName, ItemAmount, DeptDescription, ProductDescription, MembershipClubname,
                 PostingClubid, DrawerActivityID, PostDateTime, TranDate, TranTypeDescription, ValTranTypeID,
                 MemberID, ItemSalesTax, EmployeeID, PostingRegionDescription, MemberFirstname, MemberLastname,
                 EmployeeFirstname, EmployeeLastname, ReasonCodeDescription, TranItemID, TranMemberJoinDate,
                 MMSR.MembershipID, MMSR.ProductID, TranClubid, Quantity, @StartPostDate AS ReportStartDate,
                 @EndPostDate AS ReportEndDate, CO.CompanyName, CO.CorporateCode, VPG.Description AS ProductGroupDescription,
                 MMSR.ItemDiscountAmount,
                 MMSR.DiscountAmount1,
                 MMSR.DiscountAmount2,
                 MMSR.DiscountAmount3,
                 MMSR.DiscountAmount4,
                 MMSR.DiscountAmount5,
                 MMSR.Discount1,
                 MMSR.Discount2,
                 MMSR.Discount3,
                 MMSR.Discount4,
                 MMSR.Discount5,
                 VPG.RevenueReportingDepartment

          FROM vMMSRevenueReportSummary MMSR
               JOIN #Clubs CS								-- 3/13/08 GRB
                 ON MMSR.PostingClubName = CS.ClubName		-- 3/13/08 GRB
 	           JOIN dbo.vMembership MS 
		         ON MS.MembershipID = MMSR.MembershipID
 	           LEFT JOIN dbo.vCompany CO 
                 ON MS.CompanyID = CO.CompanyID
               LEFT JOIN dbo.vProductGroup PG
                 ON MMSR.ProductID = PG.ProductID
               LEFT JOIN dbo.vValProductGroup VPG
                 ON PG.ValProductGroupID = VPG.ValProductGroupID
          WHERE MMSR.PostDateTime >= @StartPostDate AND
                MMSR.PostDateTime < @AdjustedEndPostdate AND
				MMSR.ItemAmount <> 0 AND	-- 3/6/08 GRB: additional filtering to improve performance
				MMSR.DeptDescription IN ('Merchandise', 'Personal Training', 'Nutrition Coaching', 'Mind Body','Mixed Combat Arts') --12/29/2010 BSD
  END
  ELSE
  BEGIN


CREATE TABLE #RefundTranIDs (
       MMSTranRefundID INT,
       RefundMMSTranID INT,
       RefundReasonCodeID INT,
       MembershipClubID INT,
       MembershipClubName NVARCHAR(50),
       MembershipRegionID INT,
       MembershipGLClubID INT,
       MembershipGLTaxID INT,
       MembershipRegionDescription NVARCHAR(50))

INSERT INTO #RefundTranIDs
SELECT MMSTR.MMSTranRefundID,
       MMST.MMSTranID,
       MMST.ReasonCodeID,
       MS.ClubID,
       C.ClubName,
       R.ValRegionID,
       C.GLClubID,
       C.GLTaxID,
       R.Description
  FROM vMMSTranRefund  MMSTR
  JOIN vMMSTran  MMST
    ON MMST.MMSTranID = MMSTR.MMSTranID
  JOIN vMembership MS
    ON MS.MembershipID = MMST.MembershipID
  JOIN vClub C
    ON C.ClubID = MS.ClubID
  JOIN vValRegion R
    ON R.ValRegionID = C.ValRegionID
  JOIN vTranItem TI
    ON MMST.MMSTranID = TI.MMSTranID
  JOIN vProduct P
    ON P.ProductID = TI.ProductID
  JOIN vDepartment D
    ON P.DepartmentID = D.DepartmentID
  LEFT JOIN vProductGroup PG
    ON P.ProductID = PG.ProductID
 WHERE MMST.TranVoidedID IS NULL
   AND MMST.PostDateTime >= @StartPostDate
   AND MMST.PostDateTime < @AdjustedEndPostDate
   AND D.Description in('Merchandise', 'Personal Training', 'Nutrition Coaching', 'Mind Body','Mixed Combat Arts') --12/29/2010 BSD


CREATE TABLE #ReportRefunds (
       RefundMMSTranID INT,
       PostingGLTaxID INT,
       PostingGLClubID INT,
       PostingRegionDescription NVARCHAR(50),
       PostingClubName NVARCHAR(50),
       PostingMMSClubID INT)

INSERT INTO #ReportRefunds
SELECT RTID.RefundMMSTranID,
       CASE 
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.GLTaxID ELSE TranItemClub.GLTaxID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipGLTaxID
            ELSE TranClub.GLTaxID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.GLClubID ELSE TranItemClub.GLClubID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipGLClubID
            ELSE TranClub.GLClubID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranRegion.Description ELSE TranItemRegion.Description END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipRegionDescription
            ELSE TranRegion.Description
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubName ELSE TranItemClub.ClubName END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipClubName
            ELSE TranClub.ClubName
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubID ELSE TranItemClub.ClubID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipClubID
            ELSE TranClub.ClubID
       END
  FROM #RefundTranIDs  RTID
  JOIN vMMSTranRefundMMSTran  MMSTRT
    ON MMSTRT.MMSTranRefundID = RTID.MMSTranRefundID
  JOIN vMMSTran  MMST
    ON MMST.MMSTranID = MMSTRT.OriginalMMSTranID
  JOIN vClub TranClub
    ON TranClub.ClubID = MMST.ClubID
  JOIN vValRegion  TranRegion
    ON TranRegion.ValRegionID = TranClub.ValRegionID 
  LEFT JOIN vTranItem TI   --1/31/2011 BSD
    ON MMST.MMSTranID = TI.MMSTranID   --1/31/2011 BSD
  LEFT JOIN vClub TranItemClub   --1/31/2011 BSD
    ON TI.ClubID = TranItemClub.ClubID   --1/31/2011 BSD
  LEFT JOIN vValRegion TranItemRegion   --1/31/2011 BSD
    ON TranItemClub.ValRegionID = TranItemRegion.ValRegionID   --1/31/2011 BSD
GROUP BY RTID.RefundMMSTranID,
       CASE 
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.GLTaxID ELSE TranItemClub.GLTaxID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipGLTaxID
            ELSE TranClub.GLTaxID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.GLClubID ELSE TranItemClub.GLClubID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipGLClubID
            ELSE TranClub.GLClubID
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranRegion.Description ELSE TranItemRegion.Description END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipRegionDescription
            ELSE TranRegion.Description
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubName ELSE TranItemClub.ClubName END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipClubName
            ELSE TranClub.ClubName
       END,
       CASE
            WHEN TranClub.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN TranClub.ClubID ELSE TranItemClub.ClubID END   --1/31/2011 BSD
            WHEN RTID.RefundReasonCodeID = 108 OR TranClub.ClubID = 13
                 THEN RTID.MembershipClubID
            ELSE TranClub.ClubID
       END


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
        @HOLDTranItemID INT,
        @Counter INT

SET @HOLDTranItemID = -1
SET @Counter = 1

DECLARE Discount_Cursor CURSOR LOCAL READ_ONLY FOR
SELECT TI.TranItemID, TI.ItemAmount, TI.ItemDiscountAmount as TotalDiscountAmount,SP.ReceiptText,TID.AppliedDiscountAmount
  FROM vMMSTran MMST
  JOIN vTranItem TI
    ON MMST.MMSTranID = TI.MMSTranID
  JOIN vValTranType VTT
    ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN vTranItemDiscount TID
    ON TID.TranItemID = TI.TranItemID
  JOIN vPricingDiscount PD
    ON PD.PricingDiscountID = TID.PricingDiscountID
  JOIN vSalesPromotion SP
    ON PD.SalesPromotionID = SP.SalesPromotionID
  JOIN vProduct P
    ON TI.ProductID = P.ProductID
  JOIN vDepartment D
    ON P.DepartmentID = D.DepartmentID
  LEFT JOIN vProductGroup PG
    ON P.ProductID = PG.ProductID

 WHERE MMST.PostDateTime >= @StartPostDate
   AND MMST.PostDateTime < @AdjustedEndPostDate
   AND MMST.TranVoidedID IS NULL
   AND D.Description IN ('Merchandise', 'Personal Training', 'Nutrition Coaching', 'Mind Body','Mixed Combat Arts') --12/29/2010 BSD
 ORDER BY TI.TranItemID, PD.SalesPromotionID

OPEN Discount_Cursor
FETCH NEXT FROM Discount_Cursor INTO @TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount
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

    FETCH NEXT FROM Discount_Cursor INTO @TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount
    END

CLOSE Discount_Cursor
DEALLOCATE Discount_Cursor 

          SELECT 
                --C.ClubName as PostingClubName,    
                 CASE WHEN C.ClubID = 9999 THEN                                                --1/6/2011 BSD
                      CASE WHEN TranItemClub.ClubID IS NULL THEN C.ClubName                    --1/6/2011 BSD
                           ELSE TranItemClub.ClubName END                                      --1/6/2011 BSD
                      ELSE C.ClubName                                                          --1/6/2011 BSD
                 END AS PostingClubName,                                            --1/31/2011 BSD                                                  --1/6/2011 BSD
                 TI.ItemAmount, D.Description DeptDescription,
                 P.Description ProductDescription, C2.ClubName MembershipClubname,
                --MMST.ClubID as PostingClubID,     
                 CASE WHEN C.ClubID = 9999 THEN                                                --1/6/2011 BSD
                      CASE WHEN TranItemClub.ClubID IS NULL THEN C.ClubID                      --1/6/2011 BSD
                           ELSE TranItemClub.ClubID END                                        --1/6/2011 BSD
                      ELSE C.ClubID                                                            --1/6/2011 BSD
                 END AS PostingClubID,                                            --1/31/2011 BSD                                                        --1/6/2011 BSD
                 MMST.DrawerActivityID, MMST.PostDateTime, MMST.TranDate,
                 VTT.Description TranTypeDescription, MMST.ValTranTypeID, MMST.MemberID,
                 TI.ItemSalesTax, MMST.EmployeeID, 
                 --VR.Description as PostingRegionDescription,   
                 CASE WHEN C.ClubID = 9999 THEN                                                --1/6/2011 BSD
                      CASE WHEN TranItemClub.ClubID IS NULL THEN VR.Description                --1/6/2011 BSD
                           ELSE TranItemRegion.Description END                                 --1/6/2011 BSD
                      ELSE VR.Description                                                      --1/6/2011 BSD
                 END AS PostingRegionDescription,                              --1/31/2011 BSD                                             --1/6/2011 BSD
                 M.FirstName MemberFirstname, M.LastName MemberLastname, E.FirstName EmployeeFirstname,
                 E.LastName EmployeeLastname, RC.Description ReasonCodeDescription, TI.TranItemID,
                 M.JoinDate TranMemberJoinDate, MMST.MembershipID, P.ProductID, MMST.ClubID TranClubid, TI.Quantity,
                 @StartPostDate AS ReportStartDate,@EndPostDate AS ReportEndDate, CO.CompanyName, CO.CorporateCode,
                 VPG.Description AS ProductGroupDescription,
                 TI.ItemDiscountAmount,
                 #TMP.AppliedDiscountAmount1 as DiscountAmount1,
                 #TMP.AppliedDiscountAmount2 as DiscountAmount2,
                 #TMP.AppliedDiscountAmount3 as DiscountAmount3,
                 #TMP.AppliedDiscountAmount4 as DiscountAmount4,
                 #TMP.AppliedDiscountAmount5 as DiscountAmount5,
                 #TMP.ReceiptText1 as Discount1,
                 #TMP.ReceiptText2 as Discount2,
                 #TMP.ReceiptText3 as Discount3,
                 #TMP.ReceiptText4 as Discount4,
                 #TMP.ReceiptText5 as Discount5,
                 VPG.RevenueReportingDepartment

          FROM dbo.vMMSTran MMST 
               JOIN dbo.vClub C
                 ON C.ClubID = MMST.ClubID
               JOIN #Clubs CI							-- 3/13/08 GRB
                 ON C.ClubName = CI.ClubName			-- 3/13/08 GRB
               JOIN dbo.vValRegion VR
                 ON C.ValRegionID = VR.ValRegionID
               JOIN dbo.vTranItem TI
                 ON TI.MMSTranID = MMST.MMSTranID
               LEFT JOIN vClub TranItemClub                                      --1/31/2011 BSD
                 ON TI.ClubID = TranItemClub.ClubID                         --1/31/2011 BSD
               LEFT JOIN vValRegion TranItemRegion                               --1/31/2011 BSD
                 ON TranItemClub.ValRegionID = TranItemRegion.ValRegionID   --1/31/2011 BSD
               JOIN dbo.vProduct P
                 ON P.ProductID = TI.ProductID
               JOIN dbo.vDepartment D
                 ON D.DepartmentID = P.DepartmentID
               JOIN dbo.vMembership MS
                 ON MS.MembershipID = MMST.MembershipID
               JOIN dbo.vClub C2
                 ON MS.ClubID = C2.ClubID
               JOIN dbo.vValTranType VTT
                 ON MMST.ValTranTypeID = VTT.ValTranTypeID
               JOIN dbo.vMember M
                 ON M.MemberID = MMST.MemberID
               JOIN dbo.vReasonCode RC
                 ON RC.ReasonCodeID = MMST.ReasonCodeID
               LEFT OUTER JOIN dbo.vEmployee E 
                 ON MMST.EmployeeID = E.EmployeeID
  	           LEFT JOIN dbo.vCompany CO 
                 ON MS.CompanyID = CO.CompanyID
               LEFT JOIN dbo.vProductGroup PG
                 ON P.ProductID = PG.ProductID
               LEFT JOIN dbo.vValProductGroup VPG
                 ON PG.ValProductGroupID = VPG.ValProductGroupID
               LEFT JOIN #TMPDiscount #TMP  
                 ON TI.TranItemID = #TMP.TranItemID
               LEFT JOIN vMMSTranRefund MTR
                 ON MMST.MMSTranID = MTR.MMSTranID

         WHERE MMST.PostDateTime >= @StartPostDate 
		   AND MMST.PostDateTime < @AdjustedEndPostdate 
		   AND MMST.TranVoidedID IS NULL 
		   AND VTT.ValTranTypeID IN (1, 3, 4, 5) 
				--C.DisplayUIFlag = 1  
           AND C.ClubID not in (13)     --Changed condition – DisplayUIFlag may be too restrictive --10/19/2010 BSD  --1/31/2011 BSD
		   AND TI.ItemAmount <> 0	-- 3/6/08 GRB: additional filtering to improve performance
		   AND D.Description IN ('Merchandise', 'Personal Training', 'Nutrition Coaching', 'Mind Body','Mixed Combat Arts') --12/29/2010 BSD
           AND MTR.MMSTranRefundID IS NULL

  UNION ALL

	  SELECT 
--			'MMSTran' AS DataSource, @StartPostDate AS StartPostDate, @EndPostDate AS EndPostDate, 
--			@AdjustedEndPostDate AS AdjustedEndPostDate, @StartDate AS StartDate, @EndDate AS EndDate, 
			C2.ClubName as PostingClubName, 
            TI.ItemAmount, D.Description DeptDescription,
	        P.Description ProductDescription, C2.ClubName MembershipClubname, 
            C2.ClubID as PostingClubID, 
            MMST.DrawerActivityID,
	        MMST.PostDateTime, MMST.TranDate, VTT.Description TranTypeDescription,
	        MMST.ValTranTypeID, M.MemberID, TI.ItemSalesTax, MMST.EmployeeID,
            C2VR.Description as PostingRegionDescription, 
	        M.FirstName MemberFirstname, M.LastName MemberLastname,
	        E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, RC.Description ReasonCodeDescription,
	        TI.TranItemID, M.JoinDate TranMemberJoinDate, MMST.MembershipID,
	        P.ProductID, MMST.ClubID TranClubid, TI.Quantity,@StartPostDate AS ReportStartDate,@EndPostDate AS ReportEndDate, CO.CompanyName, CO.CorporateCode,
            VPG.Description AS ProductGroupDescription,
                 TI.ItemDiscountAmount,
                 #TMP.AppliedDiscountAmount1 as DiscountAmount1,
                 #TMP.AppliedDiscountAmount2 as DiscountAmount2,
                 #TMP.AppliedDiscountAmount3 as DiscountAmount3,
                 #TMP.AppliedDiscountAmount4 as DiscountAmount4,
                 #TMP.AppliedDiscountAmount5 as DiscountAmount5,
                 #TMP.ReceiptText1 as Discount1,
                 #TMP.ReceiptText2 as Discount2,
                 #TMP.ReceiptText3 as Discount3,
                 #TMP.ReceiptText4 as Discount4,
                 #TMP.ReceiptText5 as Discount5,
                 VPG.RevenueReportingDepartment
	  FROM dbo.vMMSTran MMST
	       JOIN dbo.vClub C
	         ON C.ClubID = MMST.ClubID
	       JOIN dbo.vTranItem TI
	         ON TI.MMSTranID = MMST.MMSTranID
	       JOIN dbo.vProduct P
	         ON P.ProductID = TI.ProductID
	       JOIN dbo.vDepartment D
             ON D.DepartmentID = P.DepartmentID
	       JOIN dbo.vMembership MS
	         ON MS.MembershipID = MMST.MembershipID
	       JOIN dbo.vClub C2
	         ON MS.ClubID = C2.ClubID
           JOIN #Clubs 
             ON C2.ClubName = #Clubs.ClubName
	       JOIN dbo.vValRegion C2VR
	         ON C2.ValRegionID = C2VR.ValRegionID
	       JOIN dbo.vValTranType VTT
	         ON MMST.ValTranTypeID = VTT.ValTranTypeID
	       JOIN dbo.vMember M
	         ON M.MemberID = MMST.MemberID
	       JOIN dbo.vReasonCode RC
	         ON RC.ReasonCodeID = MMST.ReasonCodeID
           LEFT JOIN dbo.vMMSTranRefund MTR 
             ON MMST.MMSTranID = MTR.MMSTranID 
	       LEFT OUTER JOIN dbo.vEmployee E
	         ON MMST.EmployeeID = E.EmployeeID
 	       LEFT JOIN dbo.vCompany CO 
                 ON MS.CompanyID = CO.CompanyID
           LEFT JOIN dbo.vProductGroup PG
             ON P.ProductID = PG.ProductID
           LEFT JOIN dbo.vValProductGroup VPG
             ON PG.ValProductGroupID = VPG.ValProductGroupID
           LEFT JOIN #TMPDiscount #TMP
             ON TI.TranItemID = #TMP.TranItemID

	  WHERE MMST.PostDateTime >= @StartPostDate
        AND MMST.PostDateTime < @AdjustedEndPostDate
        AND MMST.TranVoidedID IS NULL
        AND VTT.ValTranTypeID IN (1,3,4,5)
        AND TI.ItemAmount <> 0
        AND D.Description IN  ('Merchandise', 'Personal Training', 'Nutrition Coaching', 'Mind Body','Mixed Combat Arts') --12/29/2010 BSD
        AND C.ClubID in (13)   --10/19/2010 BSD     --1/31/2011 BSD
        AND MTR.MMSTranRefundID IS NULL

UNION ALL


SELECT #RR.PostingClubName,
       TI.ItemAmount,
       D.Description as DeptDescription,
       P.Description as ProductDescription,
       C2.ClubName as MembershipClubname,
       #RR.PostingMMSClubID as PostingClubID,
       MMST.DrawerActivityID,
       MMST.PostDateTime,
       MMST.TranDate,
       VTT.Description as TranTypeDescription,
       MMST.ValTranTypeID,
       MMST.MemberID,
       TI.ItemSalesTax,
       MMST.EmployeeID,
       #RR.PostingRegionDescription as PostingRegionDescription,
       M.FirstName as MemberFirstname,
       M.LastName as MemberLastname,
       E.FirstName as EmployeeFirstname,
       E.LastName as EmployeeLastname,
       RC.Description as ReasonCodeDescription,
       TI.TranItemID,
       M.JoinDate as TranMemberJoinDate,
       MMST.MembershipID,
       P.ProductID,
       MMST.ClubID as TranClubid,
       TI.Quantity,
       @StartPostDate as ReportStartDate,
       @EndPostDate as ReportEndDate,
       CO.CompanyName,
       CO.CorporateCode,
       VPG.Description as ProductGroupDescription,
       TI.ItemDiscountAmount,
       #TMP.AppliedDiscountAmount1 as DiscountAmount1,
       #TMP.AppliedDiscountAmount2 as DiscountAmount2,
       #TMP.AppliedDiscountAmount3 as DiscountAmount3,
       #TMP.AppliedDiscountAmount4 as DiscountAmount4,
       #TMP.AppliedDiscountAmount5 as DiscountAmount5,
       #TMP.ReceiptText1 as Discount1,
       #TMP.ReceiptText2 as Discount2,
       #TMP.ReceiptText3 as Discount3,
       #TMP.ReceiptText4 as Discount4,
       #TMP.ReceiptText5 as Discount5,
       VPG.RevenueReportingDepartment
			
  FROM vMMSTran MMST
  JOIN #ReportRefunds #RR
    ON #RR.RefundMMSTranID = MMST.MMSTranID
  JOIN vTranItem  TI
    ON TI.MMSTranID = MMST.MMSTranID
  JOIN vProduct P
    ON P.ProductID = TI.ProductID
  JOIN vDepartment D
    ON D.DepartmentID = P.DepartmentID
  JOIN vMembership MS
    ON MS.MembershipID = MMST.MembershipID
  JOIN vClub  C2
    ON MS.ClubID = C2.ClubID
  JOIN vValTranType VTT
    ON MMST.ValTranTypeID = VTT.ValTranTypeID
  JOIN vMember M
    ON M.MemberID = MMST.MemberID
  JOIN vReasonCode  RC
    ON RC.reasonCodeID = MMST.ReasonCodeID
  LEFT JOIN vEmployee E
    ON MMST.EmployeeID = E.EmployeeID  
  LEFT JOIN vCompany CO
    ON MS.CompanyID = CO.CompanyID    
  LEFT JOIN vProductGroup PG
    ON P.ProductID = PG.ProductID   
  LEFT JOIN vValProductGroup  VPG
    ON PG.ValProductGroupID = VPG.ValProductGroupID         
  LEFT JOIN #TMPDiscount #TMP
    ON TI.TranItemID = #TMP.TranItemID



DROP TABLE #RefundTranIDs
DROP TABLE #ReportRefunds
DROP TABLE #TMPDiscount

  END

DROP TABLE #Clubs				-- 3/13/08 GRB
DROP TABLE #tmpList			-- 3/13/08 GRB


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
