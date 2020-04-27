


CREATE PROC [dbo].[procCognos_PromptRegionClubForDepartmentAndDate_UDW] (
    @StartDate DATETIME,
    @DepartmentMinDimReportingHierarchyKeyList VARCHAR(8000),
    @DivisionList Varchar(8000),
    @SubdivisionList Varchar(8000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON


IF 1=0 BEGIN
       SET FMTONLY OFF
     END

----- Sample Execution
--- EXEC procCognos_PromptRegionClubForDepartmentAndDate_UDW '1/1/2019','All Departments','Personal Training','All Subdivisions'
-----

SET @StartDate = CASE WHEN @StartDate = '1/1/1900' THEN DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0) ELSE @StartDate END


DECLARE @MonthStartingDimDateKey INT,
        @MonthEndingDimDateKey INT,
		@MonthStartingDimDate DateTime,
		@MonthEndingDimDate DateTime
SELECT @MonthStartingDimDateKey = MonthStartingDimDateKey,
       @MonthEndingDimDateKey = MonthEndingDimDateKey,
	   @MonthStartingDimDate = CalendarMonthStartingDate,
	   @MonthEndingDimDate = CalendarMonthEndingDate

  FROM vReportDimDate
WHERE CalendarDate = @StartDate


--b
DECLARE @RegionType VARCHAR(50)
SET @RegionType =  (SELECT MIN(ReportRegionType) FROM fnRevenueDimReportingHierarchy_UDW(@DivisionList,@SubdivisionList,@DepartmentMinDimReportingHierarchyKeyList,'N/A',@MonthStartingDimDateKey,@MonthEndingDimDateKey))


SELECT HistoricalDimClub.dim_club_key,   ------- Name Change
       CASE WHEN @RegionType = 'PT RCL Area' THEN PTRCLArea.Description
            WHEN @RegionType = 'Member Activities Region' THEN MemberActivitiesRegion.Description
            WHEN @RegionType = 'MMS Region' THEN MMSRegion.Description
			END  ReportingRegionName,
       ActiveClub.ClubID AS MMSClubID,
       ActiveClub.ClubName,
       ActiveClub.ClubCode,
       ActiveClub.ClubActivationDate AS ClubOpenDate,
       ActiveClub.ClubCode +' - '+ ActiveClub.ClubName AS ClubCodeDashClubName,
       ClubCloseDimDate.CalendarDate ClubCloseDate
  FROM vReportDimClubHistory_UDW HistoricalDimClub
  JOIN vClub ActiveClub
    ON HistoricalDimClub.club_id = ActiveClub.ClubID
  JOIN vValRegion  MMSRegion
    ON ActiveClub.ValRegionID = MMSRegion.ValRegionID
  JOIN vValMemberActivityRegion MemberActivitiesRegion
    ON ActiveClub.ValMemberActivityRegionID = MemberActivitiesRegion.ValMemberActivityRegionID
  JOIN vValPTRCLArea PTRCLArea
    ON ActiveClub.ValPTRCLAreaID = PTRCLArea.ValPTRCLAreaID
  LEFT JOIN vReportDimDate   ClubCloseDimDate
    ON ActiveClub.ClubDeActivationDate = ClubCloseDimDate.CalendarDate
    AND ClubCloseDimDate.DimDateKey > 3
 WHERE HistoricalDimClub.effective_date_time <= @MonthEndingDimDate
   AND HistoricalDimClub.expiration_date_time > @MonthEndingDimDate
   AND HistoricalDimClub.club_id NOT IN (-1,99,100)
   AND HistoricalDimClub.club_id < 900
   AND HistoricalDimClub.club_type = 'Club'
   AND HistoricalDimClub.club_status IN ('Open','PreSale')
   AND (ActiveClub.ClubDeActivationDate is null 
        OR ActiveClub.ClubDeActivationDate > @MonthStartingDimDate)

END





