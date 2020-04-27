




---- This report returns the differences, by tender type, between
---- the TranTotalAmount and ActualTotalAmount for a selected club's
---- drawers within a selected date range.



CREATE     PROC dbo.mmsOverShort_EIS_OverShortClosing (
  @Club VARCHAR(50),
  @CloseStartDate SMALLDATETIME,
  @CloseEndDate SMALLDATETIME
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT DA.DrawerActivityID, DA.CloseDateTime, C.ClubName, 
       DA.CloseEmployeeID, DAA.TranTotalAmount, 
       DAA.ActualTotalAmount, D.Description, PT.SortOrder, 
       R.Description RegionDescription, E.FirstName, E.LastName, 
       PT.Description PaymentTypeDescription
  FROM dbo.vDrawerActivityAmount DAA
  JOIN dbo.vDrawerActivity DA
    ON DA.DrawerActivityID = DAA.DrawerActivityID
  JOIN dbo.vDrawer D
    ON DA.DrawerID = D.DrawerID
  JOIN dbo.vClub C
    ON D.ClubID = C.ClubID
  JOIN dbo.vValPaymentType PT
    ON DAA.ValPaymentTypeID = PT.ValPaymentTypeID
  JOIN dbo.vValRegion R
    ON C.ValRegionID = R.ValRegionID
  JOIN dbo.vEmployee E
    ON DA.CloseEmployeeID=E.EmployeeID
 WHERE C.ClubName = @Club AND 
       DA.CloseDateTime BETWEEN @CloseStartDate AND @CloseEndDate


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END









