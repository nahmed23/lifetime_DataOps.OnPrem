




--
-- Returns the 3 drawer activity records with the highest Activityid
--     for a single club
--
-- parameters: a single clubname string
-- EXEC mmsPosdrawer_SelectedDrawerActivityID 'Apple Valley, MN'

CREATE PROC [dbo].[mmsPosdrawer_SelectedDrawerActivityID] (
  @ClubName VARCHAR(50)
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY


SELECT TOP 3
       AL3.Description DrawerStatusDescription, 
       AL4.DrawerActivityID, 
       AL4.OpenDateTime as OpenDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, AL4.OpenDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, AL4.OpenDateTime),5,DataLength(Convert(Varchar, AL4.OpenDateTime))-12)),' '+Convert(Varchar,Year(AL4.OpenDateTime)),', '+Convert(Varchar,Year(AL4.OpenDateTime))) as OpenDateTime,
       AL4.CloseDateTime as CloseDateTime_Sort,
	   Replace(SubString(Convert(Varchar, AL4.CloseDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, AL4.CloseDateTime),5,DataLength(Convert(Varchar, AL4.CloseDateTime))-12)),' '+Convert(Varchar,Year(AL4.CloseDateTime)),', '+Convert(Varchar,Year(AL4.CloseDateTime))) as CloseDateTime

FROM dbo.vClub AL1
  JOIN dbo.vDrawer AL2
       ON AL2.ClubID=AL1.ClubID
  JOIN dbo.vDrawerActivity AL4 
       ON AL4.DrawerID=AL2.DrawerID
  JOIN dbo.vValDrawerStatus AL3
       ON AL4.ValDrawerStatusID=AL3.ValDrawerStatusID

 WHERE AL1.ClubName = @ClubName
 ORDER BY 2 DESC

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

