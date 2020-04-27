



Create   PROC dbo.mmsOverShort_w_AuditPreprocess (
  @Club VARCHAR(50),
  @CloseStartDate SMALLDATETIME,
  @CloseEndDate SMALLDATETIME
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @AuditStartDateTime DATETIME
SET @AuditStartDateTime = GETDATE()

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

-- PreProcess Audit
INSERT INTO AuditStoredProc (
    ProcedureName,
    Username,
    StartDateTime,
    Parameter1,
    Parameter2,
    Parameter3 )
  VALUES ( 
    'mmsOverShort_EIS_OverShortClosing',
    user,
    @AuditStartDateTime,
    @Club,
    @CloseStartDate,
    @CloseEndDate )

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
--C.ClubName='Bloomington, MN' AND 
--DA.CloseDateTime BETWEEN {ts '2003-08-05 00:00:00.000'} AND {ts '2003-08-15 23:59:00.000'})

-- PostProcess Audit
UPDATE AuditStoredProc
   SET EndDateTime = GETDATE(), RowsRetrieved = @@ROWCOUNT
 WHERE StartDateTime = @AuditStartDateTime AND
       ProcedureName = 'mmsOverShort_EIS_OverShortClosing' AND
       Username = user AND
       EndDateTime IS NULL

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END







