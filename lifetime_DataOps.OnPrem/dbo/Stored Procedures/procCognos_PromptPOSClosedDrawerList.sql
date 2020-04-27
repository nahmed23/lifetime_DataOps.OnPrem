
/*
-- Returns drawer activity records for a single club for a date range
--
-- parameters: a single clubname string

EXEC procCognos_PromptPOSClosedDrawerList 14, '4/1/2014', '4/17/2014'

*/
CREATE  PROC [dbo].[procCognos_PromptPOSClosedDrawerList] (
  @ClubID INT,
  @ActivityStartDate SMALLDATETIME,
  @ActivityEndDate SMALLDATETIME
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

SET @ActivityEndDate = DATEADD(DAY,1,@ActivityEndDate)  -- added a day to cover full day for @ActivityEndDate date. the date has no time stamp

SELECT VDS.Description DrawerStatusDescription, DA.DrawerActivityID, DA.OpenDateTime as OpenDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, DA.OpenDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, DA.OpenDateTime),5,DataLength(Convert(Varchar, DA.OpenDateTime))-12)),' '+Convert(Varchar,Year(DA.OpenDateTime)),', '+Convert(Varchar,Year(DA.OpenDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, DA.OpenDateTime,22),10,5) + ' ' + Right(Convert(Varchar, DA.OpenDateTime ,22),2)) as OpenDateTime,    
       DA.CloseDateTime as CloseDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, DA.CloseDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, DA.CloseDateTime),5,DataLength(Convert(Varchar, DA.CloseDateTime))-12)),' '+Convert(Varchar,Year(DA.CloseDateTime)),', '+Convert(Varchar,Year(DA.CloseDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, DA.CloseDateTime,22),10,5) + ' ' + Right(Convert(Varchar, DA.CloseDateTime ,22),2)) as CloseDateTime,    
	   C.ClubName,
	   CONVERT(VARCHAR(10), DA.DrawerActivityID)  + ' - ' +
	   convert(varchar(12),  DA.CloseDateTime, 107) +' '+ ltrim(left(right(convert(varchar(30),  DA.CloseDateTime, 100),7),5)) +' '+ right(convert(varchar(20),  DA.CloseDateTime, 100),2)
--	   Replace(SubString(Convert(Varchar, DA.CloseDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, DA.CloseDateTime),5,DataLength(Convert(Varchar, DA.CloseDateTime))-12)),' '+Convert(Varchar,Year(DA.CloseDateTime)),', '+Convert(Varchar,Year(DA.CloseDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, DA.CloseDateTime,22),10,5) + ' ' + Right(Convert(Varchar, DA.CloseDateTime ,22),2))
	      AS DrawerDetails 
	   
  FROM dbo.vClub C
  JOIN dbo.vDrawer D
       ON D.ClubID = C.ClubID
  JOIN dbo.vDrawerActivity DA 
       ON DA.DrawerID = D.DrawerID
  JOIN dbo.vValDrawerStatus VDS
       ON DA.ValDrawerStatusID = VDS.ValDrawerStatusID
 WHERE C.ClubID = @ClubID AND
       DA.CloseDateTime >= @ActivityStartDate AND DA.CloseDateTime < @ActivityEndDate

END


