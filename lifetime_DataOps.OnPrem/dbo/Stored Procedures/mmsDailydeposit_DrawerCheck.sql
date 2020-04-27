
--
-- Returns draweractivity close dates for drawers closed between a given record
--     A record is returned for drawers that didn't close on that date that includes
--     the date that drawer last closed
--
-- Parameters: A start date and end date for drawer activity closed dates to look for
--
-- EXEC mmsDailydeposit_DrawerCheck 'Apr 1, 2011' , 'Apr 2, 2011'

CREATE PROC [dbo].[mmsDailydeposit_DrawerCheck] (
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

----Find last closed drawer if no drawer was closed in datetime range
CREATE TABLE #LastClosedDrawer (DrawerActivityID INT, DrawerID INT, CloseDateTime DateTime, GLClubID Int )
INSERT INTO #LastClosedDrawer (DrawerActivityID, DrawerID, CloseDateTime, GLClubID)
SELECT DA.DrawerActivityID as DrawerActivityID,
       DA.DrawerID, 
       CASE WHEN DA.CloseDateTime < @CloseStartDate THEN DA.CloseDateTime 
            ELSE NULL END as CloseDateTime2_Sort,   
       C.GLClubID
FROM dbo.vClub C
LEFT JOIN dbo.vDrawer D 
  ON C.ClubID = D.ClubID
LEFT JOIN dbo.vDrawerActivity DA 
  ON D.DrawerID = DA.DrawerID 
 AND DA.CloseDateTime = (SELECT MAX(DA2.CloseDateTime)
                           FROM dbo.vDrawerActivity DA2
                          WHERE DA2.DrawerID = D.DrawerID
                            AND DA2.CloseDateTime <= @CloseEndDate 
                            AND DATEDIFF(Month,DA2.UTCCloseDateTime,GETDATE()) < 3)
WHERE DA.CloseDateTime < @CloseStartDate 
GROUP BY C.ClubID, C.ClubName, DA.DrawerActivityID, C.GLClubID, DA.CloseDateTime, DA.DrawerID
ORDER BY C.GLClubID
 
--- For those clubs which did not have a drawer closed in the date range, and now that we know the prior closed drawer, find the next drawer, whether closed after the date range or still un-closed
CREATE TABLE #NextClosedDrawer (DrawerActivityID INT, DrawerID INT, CloseDateTime DateTime, GLClubID Int)
INSERT INTO #NextClosedDrawer (DrawerActivityID, DrawerID, CloseDateTime, GLClubID)
SELECT DA.DrawerActivityID, DA.DrawerID, 
       DA.CloseDateTime,   
       C.GLClubID
FROM vClub C
JOIN vDrawer D 
  ON C.ClubID = D.ClubID
JOIN vDrawerActivity DA 
  ON D.DrawerID = DA.DrawerID
JOIN #LastClosedDrawer #LDC
  ON #LDC.DrawerID = DA.DrawerID
 AND #LDC.CloseDateTime > DA.OpenDateTime
 AND (#LDC.CloseDateTime < DA.CloseDateTime OR DA.CloseDateTime is Null)
GROUP BY DA.DrawerActivityID, 
         DA.DrawerID, 
         DA.CloseDateTime,   
         C.GLClubID

--- For those clubs which did not have a drawer closed in the date range, we need to know the revenue amounts by posting month from the next drawer to close, as well as its close date 
CREATE TABLE #NextClosedDrawerDetail (DrawerActivityID INT, DrawerID INT,CloseDateTime DateTime,PostMonth VARCHAR(9), PostAmount Money)
INSERT INTO #NextClosedDrawerDetail (DrawerActivityID, DrawerID, CloseDateTime, PostMonth, PostAmount)
SELECT #NCD.DrawerActivityID, 
       #NCD.DrawerID,
       #NCD.CloseDateTime, 
       DateName(m,MMSTran.PostDateTime),
       Sum(TI.ItemAmount) 
FROM #NextClosedDrawer #NCD
JOIN vMMSTran MMSTran
  ON #NCD.DrawerActivityID = MMSTran.DrawerActivityID
JOIN vTranItem TI
  ON TI.MMSTranID = MMSTran.MMSTranID
GROUP BY #NCD.DrawerActivityID, 
         #NCD.DrawerID,
         #NCD.CloseDateTime,
         DateName(m,MMSTran.PostDateTime)
 
 

---- Now we need to return data from each club, listing the drawers that did close in the date range and our collected data on the prior and next drawers for clubs which had no drawer close in the date range 
SELECT C.ClubID, 
       C.ClubName, 
       CASE WHEN DA.CloseDateTime < @CloseStartDate THEN NULL
            ELSE DA.DrawerActivityID END DrawerActivityID,
       CASE WHEN DA.CloseDateTime >= @CloseStartDate THEN DA.CloseDateTime 
            ELSE NULL END CloseDateTime_Sort,
       CASE WHEN DA.CloseDateTime >= @CloseStartDate THEN Replace(SubString(Convert(Varchar, DA.CloseDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, DA.CloseDateTime),5,DataLength(Convert(Varchar, DA.CloseDateTime))-12)),' '+Convert(Varchar,Year(DA.CloseDateTime)),', '+Convert(Varchar,Year(DA.CloseDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, DA.CloseDateTime,22),10,5) + ' ' + Right(Convert(Varchar, DA.CloseDateTime ,22),2)) 
            ELSE Null END CloseDateTime, 
       CASE WHEN DA.CloseDateTime < @CloseStartDate THEN DA.DrawerActivityID
            ELSE Null END PriorDrawerActivityID,   
       CASE WHEN DA.CloseDateTime < @CloseStartDate THEN DA.CloseDateTime 
            ELSE NULL END CloseDateTime2_Sort,
       CASE WHEN DA.CloseDateTime < @CloseStartDate THEN Replace(SubString(Convert(Varchar, DA.CloseDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, DA.CloseDateTime),5,DataLength(Convert(Varchar, DA.CloseDateTime))-12)),' '+Convert(Varchar,Year(DA.CloseDateTime)),', '+Convert(Varchar,Year(DA.CloseDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, DA.CloseDateTime,22),10,5) + ' ' + Right(Convert(Varchar, DA.CloseDateTime ,22),2)) 
            ELSE Null END CloseDateTime2,    
       C.GLClubID, 
       #NCDD.DrawerActivityID NextDrawerActivityID, 
       #NCDD.CloseDateTime NextDrawerCloseDateTime_Sort, 
       Replace(Substring(convert(varchar,#NCDD.CloseDateTime,100),1,6)+', '+Substring(convert(varchar,#NCDD.CloseDateTime,100),8,10)+' '+Substring(convert(varchar,#NCDD.CloseDateTime,100),18,2),'  ',' ') NextDrawerCloseDateTime,
       #NCDD.PostMonth, 
       #NCDD.PostAmount
FROM dbo.vClub C
LEFT JOIN dbo.vDrawer D 
  ON C.ClubID = D.ClubID
LEFT JOIN dbo.vDrawerActivity DA 
  ON D.DrawerID = DA.DrawerID 
 AND DA.CloseDateTime = (SELECT MAX(DA2.CloseDateTime)
                           FROM dbo.vDrawerActivity DA2
                          WHERE DA2.DrawerID = D.DrawerID
                            AND DA2.CloseDateTime <= @CloseEndDate 
                            AND DATEDIFF(Month,DA2.UTCCloseDateTime,GETDATE()) < 3)
LEFT JOIN #NextClosedDrawerDetail #NCDD
  ON #NCDD.DrawerID = DA.DrawerID
GROUP BY C.ClubID, 
         C.ClubName, 
         DA.DrawerActivityID, 
         C.GLClubID,
         #NCDD.DrawerActivityID, 
         DA.CloseDateTime,  
         #NCDD.CloseDateTime, 
         #NCDD.PostMonth, 
         #NCDD.PostAmount
ORDER BY C.GLClubID

 
Drop Table #LastClosedDrawer
Drop Table #NextClosedDrawer
Drop Table #NextClosedDrawerDetail   








 
-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

GRANT  EXECUTE  ON [dbo].[mmsDailydeposit_DrawerCheck]  TO [Brio_Report]

