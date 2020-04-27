
CREATE  PROC [dbo].[mmsFitnessProgram_RevenueToday]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @StartPostDate SMALLDATETIME
DECLARE @EndPostDate SMALLDATETIME
DECLARE @ClubList VARCHAR(8000)	
DECLARE @Today SMALLDATETIME
DECLARE @Yesterday DATETIME
DECLARE @Today_CurrentTime SMALLDATETIME
DECLARE @QueryDateTime datetime
DECLARE @ToDayPlus_TwoHrs DATETIME
DECLARE @Today_CurrentTime_ReportHeader DATETIME 

--declare @adjustedGETDATE datetime
--set @adjustedGETDATE = GETDATE() - day(GETDATE()) + 1

-- date range for today's transactions only
SET @Today = CONVERT(DATETIME,CONVERT(VARCHAR(11),GETDATE())) --Today (the first moment, ie: 3/4/08 00:00:00 )
SET @Today_CurrentTime = CONVERT(DATETIME,CONVERT(VARCHAR(23),GETDATE())) --Today (current time, ie: 3/4/08 14:00:00 )
SET @Today_CurrentTime_ReportHeader = CONVERT(DATETIME,CONVERT(VARCHAR(23),GETDATE())) --Today (current time, ie: 3/4/08 14:00:00 )

SET @Yesterday  = DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
SET @ToDayPlus_TwoHrs = DATEADD(hh,2, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
SET @QueryDateTime = GETDATE()

-- date range for MTD transactions only
SET @StartPostDate = cast( cast(MONTH(@Today) as varchar)+'/1/'+ cast(YEAR(@Today) as varchar) as smalldatetime)
SET @EndPostDate = @Today
SET @ClubList = 'All'

-- the report is running at midnight...
-- adjusting date and time for the report accordingly
IF @QueryDateTime <= @ToDayPlus_TwoHrs
BEGIN
	SET @Today_CurrentTime = @Today
	-- the report header will be printed as 11:59pm
	SET @Today_CurrentTime_ReportHeader = dateadd(mi,-1,@Today)
	SET @Today = @Yesterday
	SET @StartPostDate = cast( cast(MONTH(@Today) as varchar)+'/1/'+ cast(YEAR(@Today) as varchar) as smalldatetime)
	SET @EndPostDate = @Today
END


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
  LEFT JOIN vValProductGroup VPG
    ON PG.ValProductGroupID = PG.ValProductGroupID
 WHERE MMST.TranVoidedID IS NULL
   AND MMST.PostDateTime >= @Today
   AND MMST.PostDateTime < @Today_CurrentTime
   AND (D.Description IN ('Personal Training','Nutrition Coaching','Mind Body','Mixed Combat Arts')  --2/7/2011 BSD
    OR (D.Description = 'Merchandise' and VPG.RevenueReportingDepartment in ('Nutritionals','LifeLab/Testing-HRM'))) --2/7/2011 BSD


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
  LEFT JOIN vValProductGroup VPG
    ON PG.ValProductGroupID = VPG.ValProductGroupID
 WHERE MMST.PostDateTime >= @Today
   AND MMST.PostDateTime < @Today_CurrentTime
   AND MMST.TranVoidedID IS NULL
   AND (D.Description IN ('Personal Training','Nutrition Coaching','Mind Body','Mixed Combat Arts')  --2/7/2011 BSD
    OR (D.Description = 'Merchandise' and VPG.RevenueReportingDepartment in ('Nutritionals','LifeLab/Testing-HRM'))) --2/7/2011 BSD
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





	--- MTD transactions
          SELECT 
				PostingClubName, ItemAmount, DeptDescription, ProductDescription, MembershipClubname,
                 PostingClubid, DrawerActivityID, PostDateTime, TranDate, TranTypeDescription, ValTranTypeID,
                 MemberID, ItemSalesTax, EmployeeID, PostingRegionDescription, MemberFirstname, MemberLastname,
                 EmployeeFirstname, EmployeeLastname, ReasonCodeDescription, TranItemID, TranMemberJoinDate,
                 MMSR.MembershipID, MMSR.ProductID, TranClubid, Quantity, @StartPostDate AS ReportStartDate,
                 @Today_CurrentTime_ReportHeader AS ReportEndDate, CO.CompanyName, CO.CorporateCode, VPG.Description AS ProductGroupDescription,
                 ItemDiscountAmount,
                 DiscountAmount1,
                 DiscountAmount2,
                 DiscountAmount3,
                 DiscountAmount4,
                 DiscountAmount5,
                 Discount1,
                 Discount2,
                 Discount3,
                 Discount4,
                 Discount5,
                 VPG.ValProductGroupID, --2/7/2011 BSD
                 CASE WHEN VPG.RevenueReportingDepartment = 'Nutritionals' THEN 1 ELSE 0 END AS NutritionMerchandiseFlag --2/7/2011 BSD

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
                MMSR.PostDateTime < @EndPostdate AND
				MMSR.ItemAmount <> 0  -- 3/6/08 GRB: additional filtering to improve performance
			AND (MMSR.DeptDescription IN ('Personal Training','Nutrition Coaching','Mind Body','Mixed Combat Arts') --2/7/2011 BSD
             OR (MMSR.DeptDescription = 'Merchandise' and VPG.RevenueReportingDepartment in ('Nutritionals','LifeLab/Testing-HRM'))) --2/7/2011 BSD
	
	UNION ALL
    --- current day transactions; all clubs except corporate
	      SELECT 
				--C.ClubName  AS PostingClubName,                                                      --1/31/2011 BSD
                 CASE WHEN C.ClubID = 9999 THEN                                                --1/31/2011 BSD
                      CASE WHEN TranItemClub.ClubID IS NULL THEN C.ClubName                    --1/31/2011 BSD
                           ELSE TranItemClub.ClubName END                                      --1/31/2011 BSD
                      ELSE C.ClubName                                                          --1/31/2011 BSD
                 END AS PostingClubName,   
                TI.ItemAmount, D.Description DeptDescription,
                 P.Description ProductDescription, C2.ClubName AS MembershipClubname, 
                --C.ClubID  AS PostingClubid,                                                       --1/31/2011 BSD
                 CASE WHEN C.ClubID = 9999 THEN                                                --1/31/2011 BSD
                      CASE WHEN TranItemClub.ClubID IS NULL THEN C.ClubID                      --1/31/2011 BSD
                           ELSE TranItemClub.ClubID END                                        --1/31/2011 BSD
                      ELSE C.ClubID                                                            --1/31/2011 BSD
                 END AS PostingClubID,  
                 MMST.DrawerActivityID, MMST.PostDateTime, MMST.TranDate,
                 VTT.Description TranTypeDescription, MMST.ValTranTypeID, MMST.MemberID,
                 TI.ItemSalesTax, MMST.EmployeeID, 
                 --CVR.Description  AS PostingRegionDescription,                                            --1/31/2011 BSD
                 CASE WHEN C.ClubID = 9999 THEN                                                --1/31/2011 BSD
                      CASE WHEN TranItemClub.ClubID IS NULL THEN CVR.Description                --1/31/2011 BSD
                           ELSE TranItemRegion.Description END                                 --1/31/2011 BSD
                      ELSE CVR.Description                                                      --1/31/2011 BSD
                 END AS PostingRegionDescription,  
                 M.FirstName MemberFirstname, M.LastName MemberLastname, E.FirstName EmployeeFirstname,
                 E.LastName EmployeeLastname, RC.Description ReasonCodeDescription, TI.TranItemID,
                 M.JoinDate TranMemberJoinDate, MMST.MembershipID, P.ProductID, MMST.ClubID TranClubid, TI.Quantity,
                 @StartPostDate AS ReportStartDate,@Today_CurrentTime_ReportHeader  AS ReportEndDate, CO.CompanyName, CO.CorporateCode,
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
                 VPG.ValProductGroupID, --2/7/2011 BSD
                 CASE WHEN VPG.RevenueReportingDepartment = 'Nutritionals' THEN 1 ELSE 0 END AS NutritionMerchandiseFlag --2/7/2011 BSD

          FROM dbo.vMMSTran MMST 
               JOIN dbo.vClub C
                 ON C.ClubID = MMST.ClubID
               JOIN #Clubs CI							-- 3/13/08 GRB
                 ON C.ClubName = CI.ClubName			-- 3/13/08 GRB
               JOIN dbo.vValRegion CVR
                 ON C.ValRegionID = CVR.ValRegionID
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
         WHERE MMST.PostDateTime >= @Today
           AND MMST.PostDateTime < @Today_CurrentTime
           AND MMST.TranVoidedID IS NULL
           AND VTT.ValTranTypeID IN (1,3,4,5)
           AND TI.ItemAmount <> 0
           AND (D.Description IN ('Personal Training','Nutrition Coaching','Mind Body','Mixed Combat Arts')  --2/7/2011 BSD
            OR (D.Description = 'Merchandise' and VPG.RevenueReportingDepartment in ('Nutritionals','LifeLab/Testing-HRM'))) --2/7/2011 BSD
           AND C.ClubID not in (13)    --Changed condition – DisplayUIFlag may be too restrictive  --1/31/2011 BSD
           AND MTR.MMSTranRefundID IS NULL


	UNION ALL
	--- current day transactions; corporate only
	  SELECT 
			C2.ClubName AS PostingClubName, 
            TI.ItemAmount, D.Description DeptDescription,
	         P.Description ProductDescription, C2.ClubName MembershipClubname, 
             C2.ClubID AS PostingClubid,
             MMST.DrawerActivityID,
	         MMST.PostDateTime, MMST.TranDate, VTT.Description TranTypeDescription,
	         MMST.ValTranTypeID, M.MemberID, TI.ItemSalesTax, MMST.EmployeeID,
	         C2VR.Description AS PostingRegionDescription, 
             M.FirstName MemberFirstname, M.LastName MemberLastname,
	         E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, RC.Description ReasonCodeDescription,
	         TI.TranItemID, M.JoinDate TranMemberJoinDate, MMST.MembershipID,
	         P.ProductID, MMST.ClubID TranClubid, TI.Quantity,@StartPostDate AS ReportStartDate,@Today_CurrentTime_ReportHeader AS ReportEndDate, CO.CompanyName, CO.CorporateCode,
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
             VPG.ValProductGroupID, --2/7/2011 BSD
             CASE WHEN VPG.RevenueReportingDepartment = 'Nutritionals' THEN 1 ELSE 0 END AS NutritionMerchandiseFlag --2/7/2011 BSD

	  FROM dbo.vMMSTran MMST
	       JOIN dbo.vClub C
	         ON C.ClubID = MMST.ClubID
           JOIN dbo.vValRegion CVR
	         ON C.ValRegionID = CVR.ValRegionID
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

	  WHERE MMST.PostDateTime >= @Today
        AND MMST.PostDateTime < @Today_CurrentTime
        AND MMST.TranVoidedID IS NULL
        AND VTT.ValTranTypeID IN (1,3,4,5)
        AND TI.ItemAmount <> 0
        AND (D.Description IN ('Personal Training','Nutrition Coaching','Mind Body','Mixed Combat Arts')  --2/7/2011 BSD
         OR (D.Description = 'Merchandise' and VPG.RevenueReportingDepartment in ('Nutritionals','LifeLab/Testing-HRM'))) --2/7/2011 BSD
        AND C.ClubID in (13)   --1/31/2011 BSD
        ANd MTR.MMSTranRefundID IS NULL

UNION ALL 
--This query returns automated refund transactions for the reporting date (today) as defined in the earlier temp table #ReportRefunds)

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
       @Today_CurrentTime_ReportHeader as ReportEndDate,
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
       VPG.ValProductGroupID, --2/7/2011 BSD
       CASE WHEN VPG.RevenueReportingDepartment = 'Nutritionals' THEN 1 ELSE 0 END AS NutritionMerchandiseFlag --2/7/2011 BSD

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




  DROP TABLE #Clubs				-- 3/13/08 GRB
  DROP TABLE #tmpList			-- 3/13/08 GRB
DROP TABLE #RefundTranIDs
DROP TABLE #ReportRefunds
DROP TABLE #TMPDiscount

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
