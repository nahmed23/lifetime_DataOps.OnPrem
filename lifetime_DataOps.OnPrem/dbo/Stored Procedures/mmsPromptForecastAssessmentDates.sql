
CREATE PROC [dbo].[mmsPromptForecastAssessmentDates] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

CREATE TABLE #Years (Year VARCHAR(4))
INSERT INTO #Years
SELECT Convert(Varchar,Year(GetDate()))
UNION
SELECT Convert(Varchar,Year(GetDate())+1)

CREATE TABLE #Months (Month VARCHAR(2))
INSERT INTO #Months
SELECT '01'
UNION
SELECT '02'
UNION
SELECT '03'
UNION
SELECT '04'
UNION
SELECT '05'
UNION
SELECT '06'
UNION
SELECT '07'
UNION
SELECT '08'
UNION
SELECT '09'
UNION
SELECT '10'
UNION
SELECT '11'
UNION
SELECT '12'

SELECT #Years.Year+'-'+#Months.Month YearMonth,
       Replace(Substring(convert(varchar,Convert(DateTime,#Months.Month+'/'+Convert(Varchar,VAD.AssessmentDay)+'/'+#Years.Year),100),1,6)+', '+Substring(convert(varchar,Convert(DateTime,#Months.Month+'/'+Convert(Varchar,VAD.AssessmentDay)+'/'+#Years.Year),100),8,4),'  ',' ') AssessmentDate,
       CASE WHEN Replace(Substring(convert(varchar,Convert(DateTime,#Months.Month+'/'+Convert(Varchar,VAD.AssessmentDay)+'/'+#Years.Year),100),1,6)+', '+Substring(convert(varchar,Convert(DateTime,#Months.Month+'/'+Convert(Varchar,VAD.AssessmentDay)+'/'+#Years.Year),100),8,4),'  ',' ') Like '% 1,%'
            THEN 1
            ELSE 0
       END FirstOfMonthFlag
FROM vValAssessmentDay VAD
CROSS JOIN #Years
CROSS JOIN #Months
WHERE #Years.Year+'-'+#Months.Month >= STUFF(LEFT(CONVERT(VARCHAR,GetDate(),112),6),5,0,'-')
AND Replace(Substring(convert(varchar,Convert(DateTime,#Months.Month+'/'+Convert(Varchar,VAD.AssessmentDay)+'/'+#Years.Year),100),1,6)+', '+Substring(convert(varchar,Convert(DateTime,#Months.Month+'/'+Convert(Varchar,VAD.AssessmentDay)+'/'+#Years.Year),100),8,4),'  ',' ') > GetDate()
ORDER BY YearMonth, VAD.AssessmentDay

DROP TABLE #Years
DROP TABLE #Months


END
