
--
-- Returns drawer activity records for a single club for a date range
--
-- parameters: a single clubname string
--


CREATE  PROC [dbo].[mmsPosdrawerclosed_SelectedDrawerActivityID] (
  @ClubName VARCHAR(50),
  @ActivityStartDate SMALLDATETIME,
  @ActivityEndDate SMALLDATETIME
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

SELECT VDS.Description DrawerStatusDescription, DA.DrawerActivityID, DA.OpenDateTime as OpenDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, DA.OpenDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, DA.OpenDateTime),5,DataLength(Convert(Varchar, DA.OpenDateTime))-12)),' '+Convert(Varchar,Year(DA.OpenDateTime)),', '+Convert(Varchar,Year(DA.OpenDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, DA.OpenDateTime,22),10,5) + ' ' + Right(Convert(Varchar, DA.OpenDateTime ,22),2)) as OpenDateTime,    
       DA.CloseDateTime as CloseDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, DA.CloseDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, DA.CloseDateTime),5,DataLength(Convert(Varchar, DA.CloseDateTime))-12)),' '+Convert(Varchar,Year(DA.CloseDateTime)),', '+Convert(Varchar,Year(DA.CloseDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, DA.CloseDateTime,22),10,5) + ' ' + Right(Convert(Varchar, DA.CloseDateTime ,22),2)) as CloseDateTime,    
	   C.ClubName 
  FROM dbo.vClub C
  JOIN dbo.vDrawer D
       ON D.ClubID = C.ClubID
  JOIN dbo.vDrawerActivity DA 
       ON DA.DrawerID = D.DrawerID
  JOIN dbo.vValDrawerStatus VDS
       ON DA.ValDrawerStatusID = VDS.ValDrawerStatusID
 WHERE C.ClubName = @ClubName AND
       DA.CloseDateTime BETWEEN @ActivityStartDate AND @ActivityEndDate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

