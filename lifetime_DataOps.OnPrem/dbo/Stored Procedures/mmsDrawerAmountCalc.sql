



CREATE PROCEDURE dbo.mmsDrawerAmountCalc
  @Drawer INT = NULL

AS

  DECLARE @ChangeRenderedTotal MONEY
  DECLARE @DrawerActivityID    INT

  -- This procedure provides a summary calculation for an individual cash drawer
  --   using @Drawer as the DrawerActivityID.

BEGIN

  SET XACT_ABORT ON
  SET NOCOUNT ON

  SET @DrawerActivityID = @Drawer

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  -- Create a temp table with the Drawer Sums
  SELECT ISNULL(DrawerActivityID, @DrawerActivityID) DrawerActivityID,
         VPT.ValPaymentTypeID,
         VPT.Description,
         ISNULL(TotalPaymentAmount, 0.00) TranTotalAmount,
         VPT.SortOrder
    INTO #T1
    FROM vValPaymentType VPT
         LEFT JOIN (SELECT MT.DrawerActivityID,
                           P.ValPaymentTypeID,
                           SUM(ISNULL(P.PaymentAmount,0)) TotalPaymentAmount
                      FROM vMMSTran MT
                           JOIN vPayment P
                             ON MT.MMSTranID = P.MMSTranID 
                           JOIN vValPaymentType VPT
                             ON VPT.ValPaymentTypeID = P.ValPaymentTypeID
                     WHERE MT.DrawerActivityID = @DrawerActivityID
                       AND MT.TranVoidedID IS NULL  
                     GROUP BY MT.DrawerActivityID,
                           P.ValPaymentTypeID) X
           ON VPT.ValPaymentTypeID = X.ValPaymentTypeID
    WHERE VPT.ViewPaymentTypeFlag = 1
   ORDER BY VPT.SortOrder

  SELECT @ChangeRenderedTotal = SUM(ISNULL(ChangeRendered,0))
    FROM vMMSTran
   WHERE DrawerActivityID = @DrawerActivityID
     AND TranVoidedID IS NULL

  -- Remove the Change Rendered for Cash payments
  UPDATE #T1
     SET TranTotalAmount = TranTotalAmount - @ChangeRenderedTotal
   WHERE ValPaymentTypeID = 1

  -- Return Result Set
  SELECT DrawerActivityID,
         ValPaymentTypeID,
         Description,
         TranTotalAmount
    FROM #T1
   ORDER BY SortOrder

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



