
CREATE  PROC [dbo].[mmsTranddt_Trandt_ByRegion](
            @RegionIDList VARCHAR(8000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
EXEC procParseStringList @RegionIDList
CREATE TABLE #Clubs (ClubID INT)
INSERT INTO #Clubs (ClubID)
SELECT vClub.ClubID 
  FROM vClub 
  JOIN vValRegion ON vClub.ValRegionID= vValRegion.ValRegionID
 WHERE vValRegion.ValRegionID IN (SELECT StringField FROM #tmpList)

DECLARE @StartDate DATETIME,
        @EndDate DATETIME,
        @FirstOfMonth DATETIME

	SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,dateadd(mm,0,GETDATE()),112),1,6) + '01', 112)
	SET @StartDate  =  DATEADD(mm,-1,@FirstOfMonth)
	SET @EndDate  =  DATEADD(ss,-1,@FirstOfMonth)

--LFF Acquisition changes begin
SELECT ms.MembershipID,
	CASE WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 160 THEN 220 --Cary
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 159 THEN 219 --Dublin
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 40 THEN 218  --Easton
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 30 THEN 214  --Indianapolis
		 ELSE ms.ClubID END ClubID,
	ms.CreatedDateTime
INTO #Membership
FROM vMembership ms WITH (NOLOCK)
LEFT JOIN vMembershipTypeAttribute mta WITH (NOLOCK)
  ON mta.MembershipTypeID = ms.MembershipTypeID
 AND mta.ValMembershipTypeAttributeID = 28 --Acquisition

CREATE INDEX IX_MembershipID on #Membership(MembershipID)
CREATE INDEX IX_ClubID ON #Membership(ClubID)

SELECT DISTINCT mt.MMSTranID, 
		CASE WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 160 THEN 220 --Cary
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 159 THEN 219 --Dublin
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 40  THEN 218 --Easton
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 30  THEN 214 --Indianapolis
			 ELSE mt.ClubID END ClubID,
	   mt.MembershipID, mt.MemberID, mt.DrawerActivityID,
       mt.TranVoidedID, mt.ReasonCodeID, mt.ValTranTypeID, mt.DomainName, mt.ReceiptNumber, 
       mt.ReceiptComment, mt.PostDateTime, mt.EmployeeID, mt.TranDate, mt.POSAmount,
       mt.TranAmount, mt.OriginalDrawerActivityID, mt.ChangeRendered, mt.UTCPostDateTime, 
       mt.PostDateTimeZone, mt.OriginalMMSTranID, mt.TranEditedFlag,
       mt.TranEditedEmployeeID, mt.TranEditedDateTime, mt.UTCTranEditedDateTime, 
       mt.TranEditedDateTimeZone, mt.ReverseTranFlag, mt.ComputerName, mt.IPAddress,
	   mt.ValCurrencyCodeID,mt.CorporatePartnerID,mt.ConvertedAmount,mt.ConvertedValCurrencyCodeID
INTO #MMSTranNonArchive
FROM vMMSTranNonArchive mt WITH (NOLOCK)
JOIN #Membership ms
  ON ms.MembershipID = mt.MembershipID
LEFT JOIN vTranItem ti WITH (NOLOCK)
  ON ti.MMSTranID = mt.MMSTranID
 AND mt.ValTranTypeID IN (1,4)
 AND mt.ClubID IN (30,40,159,160)
 AND (ti.ProductID IN (1497,3100)
		OR ti.ProductID IN (SELECT mta.MembershipTypeID 
							FROM vMembershipTypeAttribute mta WITH (NOLOCK)
							WHERE mta.ValMembershipTypeAttributeID = 28) --Acquisition
	 )
WHERE  mt.PostDateTime >= @StartDate --limit from result query
   AND mt.PostDateTime <= @EndDate --limit from result query
   
CREATE INDEX IX_ClubID on #MMSTranNonArchive(ClubID)
CREATE INDEX IX_PostDateTime on #MMSTranNonArchive(PostDateTime)
--LFF Acquisition changes end
/***************************************/



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
  FROM #MMSTranNonArchive MMST
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
 WHERE MMST.PostDateTime >= @StartDate
   AND MMST.PostDateTime <= @EndDate
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

/********     3/11/2011 BSD ***************/
CREATE TABLE #LocalCurrencyPaymentTypeAmounts (MMSTranID INT, PaymentTypeAmount Varchar(1000))
CREATE TABLE #USDPaymentTypeAmounts (MMSTranID INT, PaymentTypeAmount Varchar(1000))
DECLARE @MMSTranID INT,
        @PaymentType Varchar(50),
        @LocalCurrencyPaymentAmount Varchar(50),
        @USDPaymentAmount Varchar(50),
        @CurrentMMSTranID INT
SET @CurrentMMSTranID = -1

DECLARE PaymentTypeAmount_Cursor CURSOR LOCAL READ_ONLY FOR
SELECT P.MMSTranID,PT.Description,Convert(Varchar,P.PaymentAmount) LocalCurrencyPaymentAmount, 
       Convert(Varchar,P.PaymentAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate) USDPaymentAmount
FROM vPayment P
JOIN vValPaymentType PT ON P.ValPaymentTypeID=PT.ValPaymentTypeID
JOIN #MMSTranNonArchive MMST ON P.MMSTranID = MMST.MMSTranID
JOIN #Membership MS ON MMST.MembershipID = MS.MembershipID
JOIN vClub C ON MMST.ClubID = C.ClubID
JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
JOIN vMonthlyAverageExchangeRate USDMonthlyAverageExchangeRate
  ON VCC.CurrencyCode = USDMonthlyAverageExchangeRate.FromCurrencyCode
 AND 'USD' = USDMonthlyAverageExchangeRate.ToCurrencyCode
 AND MMST.PostDateTime >= USDMonthlyAverageExchangeRate.FirstOfMonthDate
 AND Convert(Datetime,Convert(Varchar,MMST.PostDateTime,101),101) <= USDMonthlyAverageExchangeRate.EndOfMonthDate
WHERE CASE WHEN MMST.ClubID = 13 THEN MS.ClubID ELSE MMST.ClubID END in (SELECT ClubID FROM #Clubs)
  AND MMST.PostDateTime BETWEEN @StartDate AND @EndDate 
ORDER BY P.MMSTranID

OPEN PaymentTypeAmount_Cursor
FETCH NEXT FROM PaymentTypeAmount_Cursor INTO @MMSTranID,@PaymentType,@LocalCurrencyPaymentAmount,@USDPaymentAmount
WHILE (@@FETCH_STATUS = 0)
    BEGIN
		IF @MMSTranID = @CurrentMMSTranID
           BEGIN
                UPDATE #LocalCurrencyPaymentTypeAmounts
                   SET PaymentTypeAmount = PaymentTypeAmount + ', ' + @PaymentType + ' ' + @LocalCurrencyPaymentAmount
                 WHERE #LocalCurrencyPaymentTypeAmounts.MMSTranID = @MMSTranID

                UPDATE #USDPaymentTypeAmounts
                   SET PaymentTypeAmount = PaymentTypeAmount + ', ' + @PaymentType + ' ' + @USDPaymentAmount
                 WHERE #USDPaymentTypeAmounts.MMSTranID = @MMSTranID
           END
        ELSE
           BEGIN
               INSERT INTO #LocalCurrencyPaymentTypeAmounts (MMSTranID, PaymentTypeAmount) VALUES (@MMSTranID, @PaymentType + ' ' + @LocalCurrencyPaymentAmount)
               INSERT INTO #USDPaymentTypeAmounts (MMSTranID, PaymentTypeAmount) VALUES (@MMSTranID, @PaymentType + ' ' + @USDPaymentAmount)
               SET @CurrentMMSTranID = @MMSTranID
               
           END
    FETCH NEXT FROM PaymentTypeAmount_Cursor INTO @MMSTranID,@PaymentType,@LocalCurrencyPaymentAmount,@USDPaymentAmount
    END
CLOSE PaymentTypeAmount_Cursor
DEALLOCATE PaymentTypeAmount_Cursor 
/**************************/

SELECT CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN VR1.Description 
                                            ELSE TranItemRegion.Description END 
            ELSE VR1.Description 
       END AS Region,
       CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN C1.ClubName 
                                            ELSE TranItemClub.ClubName END 
            ELSE C1.ClubName 
       END AS ClubName,
       CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN VCC1.CurrencyCode 
                                            ELSE TranItemValCurrencyCode.CurrencyCode END 
            ELSE VCC1.CurrencyCode 
       END AS CurrencyCode,
       CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                            ELSE TranItemUSDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate END 
            ELSE USDmonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
       END AS MonthlyAverageExchangeRate,
       VTT.Description AS TranType,
       E.FirstName AS EmployeeFirstName, E.LastName AS EmployeeLastName, 
       M.FirstName AS MemberFirstName, M.LastName AS MemberLastName,
       MMST.MemberID, 
       MMST.TranAmount LocalCurrencyTranAmount,
       MMST.TranAmount * CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                                              ELSE TranItemUSDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate END 
                              ELSE USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                         END AS USDTranAmount,
       MMST.TranDate, MMST.PostDateTime AS Postdate, P.DepartmentID,
       MMST.MMSTranID, 
       TI.ItemAmount LocalCurrencyItemAmount, 
       TI.ItemAmount * CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                                            ELSE TranItemUSDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate END 
                            ELSE USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                       END AS USDItemAmount,
       TI.ItemSalesTax LocalCurrencyItemSalesTax,
       TI.ItemSalesTax * CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                                              ELSE TranItemUSDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate END 
                              ELSE USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                         END AS USDItemSalesTax,
       MMST.POSAmount LocalCurrencyPOSAmount, 
       MMST.POSAmount * CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                                             ELSE TranItemUSDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate END 
                             ELSE USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                        END AS USDPOSAmount,
       MMST.TranVoidedID, TI.TranItemID,
       VR2.Description AS MembershipRegion, 
       C2.ClubName AS MembershipClub, 
       CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN C1.ClubID 
                                            ELSE TranItemClub.ClubID END 
            ELSE C1.ClubID 
       END AS ClubID,
       CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN VR1.Description 
                                            ELSE TranItemRegion.Description END 
            ELSE VR1.Description 
       END AS TranRegionDescription,
       P.Description AS ProductDescription, 
       MMST.DrawerActivityID,D.Description AS DeptDescription, 
       MS.CreatedDateTime AS MembershipCreatedDateTime,
	   E.EmployeeID as EmployeeNumber,
       VRC.description,
       MMST.MembershipID,
       P.GLAccountNumber,
       P.GLSubAccountNumber,
       GLA.DiscountGLAccount,
       #TMP.TotalDiscountAmount LocalCurrencyTotalDiscountAmount,
       #TMP.TotalDiscountAmount * CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                                                       ELSE TranItemUSDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate END 
                                       ELSE USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                  END AS USDTotalDiscountAmount,
       TI.ItemAmount + ISNULL(#TMP.TotalDiscountAmount,0) LocalCurrencyGrossTranAmount,
       (TI.ItemAmount + ISNULL(#TMP.TotalDiscountAmount,0)) * CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                                                                                   ELSE TranItemUSDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate END 
                                                                   ELSE USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                                              END AS USDGrossTranAmount,
       #TMP.AppliedDiscountAmount1 AS LocalCurrencyDiscountAmount1,
       #TMP.AppliedDiscountAmount1 * CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                                                          ELSE TranItemUSDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate END 
                                          ELSE USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                     END AS USDDiscountAmount1,
       #TMP.AppliedDiscountAmount2 AS LocalCurrencyDiscountAmount2,
       #TMP.AppliedDiscountAmount2 * CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                                                          ELSE TranItemUSDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate END 
                                          ELSE USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                     END AS USDDiscountAmount2,
       #TMP.AppliedDiscountAmount3 AS LocalCurrencyDiscountAmount3,
       #TMP.AppliedDiscountAmount3 * CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                                                          ELSE TranItemUSDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate END 
                                          ELSE USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                     END AS USDDiscountAmount3,
       #TMP.AppliedDiscountAmount4 AS LocalCurrencyDiscountAmount4,
       #TMP.AppliedDiscountAmount4 * CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                                                          ELSE TranItemUSDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate END 
                                          ELSE USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                     END AS USDDiscountAmount4,
       #TMP.AppliedDiscountAmount5 AS LocalCurrencyDiscountAmount5,
       #TMP.AppliedDiscountAmount5 * CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                                                          ELSE TranItemUSDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate END 
                                          ELSE USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate 
                                     END AS USDDiscountAmount5,
       #TMP.ReceiptText1 as Discount1,
       #TMP.ReceiptText2 as Discount2,
       #TMP.ReceiptText3 as Discount3,
       #TMP.ReceiptText4 as Discount4,
       #TMP.ReceiptText5 as Discount5,
       DA.CloseDateTime DrawerCloseDateTime, --3/8/2011 BSD
       #LocalCurrencyPaymentTypeAmounts.PaymentTypeAmount LocalCurrencyPaymentTypeAmounts, --3/8/2011 BSD
       #USDPaymentTypeAmounts.PaymentTypeAmount USDPaymentTypeAmounts,
       VPSC.Description SalesChannel
  FROM dbo.vClub C1
  JOIN dbo.#MMSTranNonArchive MMST
       ON C1.ClubID = MMST.ClubID
  JOIN vValCurrencyCode VCC1
       ON C1.ValCurrencyCodeID = VCC1.ValCurrencyCodeID
  JOIN vMonthlyAverageExchangeRate USDMonthlyAverageExchangeRate
       ON VCC1.CurrencyCode = USDMonthlyAverageExchangeRate.FromCurrencyCode
      AND 'USD' = USDMonthlyAverageExchangeRate.ToCurrencyCode
      AND MMST.PostDateTime >= USDMonthlyAverageExchangeRate.FirstOfMonthDate
      AND Convert(Datetime,Convert(Varchar,MMST.PostDateTime,101),101) <= USDMonthlyAverageExchangeRate.EndOfMonthDate
  JOIN dbo.vDrawerActivity DA --3/8/2011 BSD
       ON MMST.DrawerActivityID = DA.DrawerActivityID --3/8/2011 BSD
  LEFT JOIN #LocalCurrencyPaymentTypeAmounts --3/8/2011 BSD
       ON MMST.MMSTranID = #LocalCurrencyPaymentTypeAmounts.MMSTranID --3/8/2011 BSD
  LEFT JOIN #USDPaymentTypeAmounts
       ON MMST.MMSTranID = #USDPaymentTypeAmounts.MMSTranID
  JOIN dbo.vValRegion VR1
       ON VR1.ValRegionID = C1.ValRegionID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValTranType VTT
       ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN #Membership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValRegion VR2
       ON C2.ValRegionID = VR2.ValRegionID
  JOIN dbo.vReasonCode VRC
       ON	VRC.ReasonCodeID = MMST.ReasonCodeID
  LEFT JOIN dbo.vEmployee E
       ON (E.EmployeeID = MMST.EmployeeID)
  LEFT JOIN dbo.vTranItem TI
       ON (MMST.MMSTranID = TI.MMSTranID)
  LEFT JOIN dbo.vClub TranItemClub
       ON TI.ClubID = TranItemClub.ClubID
  LEFT JOIN dbo.vValRegion TranItemRegion
       ON TranItemClub.ValRegionID = TranItemRegion.ValRegionID
  LEFT JOIN vValCurrencyCode TranItemValCurrencyCode
       ON TranItemClub.ValCurrencyCodeID = TranItemValCurrencyCode.ValCurrencyCodeID
  LEFT JOIN vMonthlyAverageExchangeRate TranItemUSDMonthlyAverageExchangeRate
       ON TranItemValCurrencyCode.CurrencyCode = TranItemUSDmonthlyAverageExchangeRate.FromCurrencyCode
      AND 'USD' = TranItemUSDMonthlyAverageExchangeRate.ToCurrencyCode
      AND MMST.PostDateTime >= TranItemUSDMonthlyAverageExchangeRate.FirstOfMonthDate
      AND Convert(Datetime,Convert(Varchar,MMST.PostDateTime,101),101) <= TranItemUSDMonthlyAverageExchangeRate.EndOfMonthDate
  LEFT JOIN dbo.vProduct P
       ON (TI.ProductID = P.ProductID)
  LEFT JOIN dbo.vDepartment D
       ON (P.DepartmentID = D.DepartmentID) 
  LEFT JOIN vGLAccount GLA
    ON P.GLAccountNumber = GLA.RevenueGLAccountNumber
  LEFT JOIN #TMPDiscount  #TMP
    ON TI.TranItemID =  #TMP.TranItemID
  LEFT JOIN vWebOrderMMSTran WOMT
    ON MMST.MMSTranID = WOMT.MMSTranID
  LEFT JOIN vWebOrder WO
    ON WOMT.WebOrderID = WO.WebOrderID
  LEFT JOIN vValProductSalesChannel VPSC
    ON WO.ValProductSalesChannelID = VPSC.ValProductSalesChannelID 
 WHERE CASE WHEN C1.ClubID = 9999 THEN ISNULL(TI.ClubID, C1.ClubID)
            ELSE C1.ClubID END IN (SELECT ClubID FROM #Clubs) 
       AND MMST.PostDateTime BETWEEN @StartDate AND @EndDate 
       AND C1.ClubID not in(13)

UNION ALL

SELECT VR2.Description AS Region, 
       C2.ClubName, 
       VCC.CurrencyCode,
       USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate,
       VTT.Description AS TranType,
       E.FirstName AS EmployeeFirstName, E.LastName AS EmployeeLastName, 
       M.FirstName AS MemberFirstName, M.LastName AS MemberLastName,
       M.MemberID, 
       MMST.TranAmount LocalCurrencyTranAmount,
       MMST.TranAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDTranAmount,
       MMST.TranDate, MMST.PostDateTime AS Postdate, D.DepartmentID,
       MMST.MMSTranID, 
       TI.ItemAmount LocalCurrencyItemAmount, 
       TI.ItemAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDItemAmount,
       TI.ItemSalesTax LocalCurrencyItemSalesTax,
       TI.ItemSalesTax * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDItemSalesTax,
       MMST.POSAmount LocalCurrencyPOSAmount, 
       MMST.POSAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDPOSAmount,
       MMST.TranVoidedID, TI.TranItemID,
       VR2.Description AS MembershipRegion, 
       C2.ClubName AS MembershipClub, C2.ClubID,
       VR2.Description AS TranRegionDescription, 
       P.Description AS ProductDescription, 
       MMST.DrawerActivityID,D.Description AS DeptDescription, 
       MS.CreatedDateTime AS MembershipCreatedDateTime,
	   E.EmployeeID as EmployeeNumber,
	   VRC.description,
       MMST.MembershipID,
       P.GLAccountNumber,
       P.GLSubAccountNumber,
       GLA.DiscountGLAccount,
       #TMP.TotalDiscountAmount LocalCurrencyTotalDiscountAmount,
       #TMP.TotalDiscountAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDTotalDiscountAmount,
       TI.ItemAmount + ISNULL(#TMP.TotalDiscountAmount,0) as LocalCurrencyGrossTranAmount,
       (TI.ItemAmount + ISNULL(#TMP.TotalDiscountAmount,0)) * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDGrossTranAmount,
       #TMP.AppliedDiscountAmount1 as LocalCurrencyDiscountAmount1,
       #TMP.AppliedDiscountAmount1 * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate as USDDiscountAmount1,
       #TMP.AppliedDiscountAmount2 as LocalCurrencyDiscountAmount2,
       #TMP.AppliedDiscountAmount2 * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate as USDDiscountAmount2,
       #TMP.AppliedDiscountAmount3 as LocalCurrencyDiscountAmount3,
       #TMP.AppliedDiscountAmount3 * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate as USDDiscountAmount3,
       #TMP.AppliedDiscountAmount4 as LocalCurrencyDiscountAmount4,
       #TMP.AppliedDiscountAmount4 * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate as USDDiscountAmount4,
       #TMP.AppliedDiscountAmount5 as LocalCurrencyDiscountAmount5,
       #TMP.AppliedDiscountAmount5 * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate as USDDiscountAmount5,
       #TMP.ReceiptText1 as Discount1,
       #TMP.ReceiptText2 as Discount2,
       #TMP.ReceiptText3 as Discount3,
       #TMP.ReceiptText4 as Discount4,
       #TMP.ReceiptText5 as Discount5,
       DA.CloseDateTime DrawerCloseDateTime, --3/8/2011 BSD
       #LocalCurrencyPaymentTypeAmounts.PaymentTypeAmount LocalCurrencyPaymentTypeAmounts, --3/8/2011 BSD
       #USDPaymentTypeAmounts.PaymentTypeAmount USDPaymentTypeAmounts,
       VPSC.Description SalesChannel
  FROM dbo.vClub C1
  JOIN dbo.#MMSTranNonArchive MMST
       ON C1.ClubID = MMST.ClubID
  JOIN dbo.vDrawerActivity DA --3/8/2011 BSD
       ON MMST.DrawerActivityID = DA.DrawerActivityID --3/8/2011 BSD
  LEFT JOIN #LocalCurrencyPaymentTypeAmounts --3/8/2011 BSD
       ON MMST.MMSTranID = #LocalCurrencyPaymentTypeAmounts.MMSTranID --3/8/2011 BSD
  LEFT JOIN #USDPaymentTypeAmounts
       ON MMST.MMSTRanID = #USDPaymentTypeAmounts.MMSTranID
  JOIN dbo.vValRegion VR1
       ON VR1.ValRegionID = C1.ValRegionID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValTranType VTT
       ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN #Membership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN vValCurrencyCode VCC
       ON C2.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN vMonthlyAverageExchangeRate USDMonthlyAverageExchangeRate
       ON VCC.CurrencyCode = USDMonthlyAverageExchangeRate.FromCurrencyCode
      AND 'USD' = USDMonthlyAverageExchangeRate.ToCurrencyCode
      AND MMST.PostDateTime >= USDMonthlyAverageExchangeRate.FirstOfMonthDate
      AND Convert(Datetime,Convert(Varchar,MMST.PostDateTime,101),101) <= USDMonthlyAverageExchangeRate.EndOfMonthDate
  JOIN dbo.vValRegion VR2
       ON C2.ValRegionID = VR2.ValRegionID
  JOIN dbo.vReasonCode VRC
       ON	VRC.ReasonCodeID = MMST.ReasonCodeID
  LEFT JOIN dbo.vEmployee E
       ON (E.EmployeeID = MMST.EmployeeID)
  LEFT JOIN dbo.vTranItem TI
       ON (MMST.MMSTranID = TI.MMSTranID)
  LEFT JOIN dbo.vProduct P
       ON (TI.ProductID = P.ProductID)
  LEFT JOIN dbo.vDepartment D
       ON (P.DepartmentID = D.DepartmentID) 
  LEFT JOIN vGLAccount GLA
    ON P.GLAccountNumber = GLA.RevenueGLAccountNumber
  LEFT JOIN #TMPDiscount  #TMP
    ON TI.TranItemID =  #TMP.TranItemID
  LEFT JOIN vWebOrderMMSTran WOMT
    ON MMST.MMSTranID = WOMT.MMSTranID
  LEFT JOIN vWebOrder WO
    ON WOMT.WebOrderID = WO.WebOrderID
  LEFT JOIN vValProductSalesChannel VPSC
    ON WO.ValProductSalesChannelID = VPSC.ValProductSalesChannelID
 WHERE C2.ClubID IN (SELECT ClubID FROM #Clubs) 
       AND MMST.PostDateTime BETWEEN @StartDate AND @EndDate 
       AND MMST.ClubID in (13)

DROP TABLE #Clubs
DROP TABLE #tmpList
DROP TABLE #TMPDiscount

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


