
CREATE PROC [dbo].[procCognos_CardFulfillment] (
    @StartDate DATETIME,
    @EndDate DATETIME,
	@ClubIDList VARCHAR(1000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON



DECLARE @AdjustedEndDate DATETIME
DECLARE @HeaderFulfillmentRequestDateRange VARCHAR(50) 
DECLARE @ReportRunDateTime VARCHAR(21)
 
SET @AdjustedEndDate = DateAdd(day,1,@EndDate)
SET @HeaderFulfillmentRequestDateRange = convert(varchar(12), @StartDate, 107) + '  through ' + convert(varchar(12), @EndDate, 107)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')

CREATE TABLE #SpecialCards (ClubName varchar(50), UniqueMembershipCount INT, CardCount INT)
CREATE TABLE #ReplacementCards (ClubName varchar(50), UniqueMembershipCount INT, CardCount INT)
CREATE TABLE #NewMemberships (ClubName varchar(50), UniqueMembershipCount INT, CardCount INT)

-- list of clubs 
CREATE TABLE #tmpList(StringField VARCHAR(50))
CREATE TABLE #ClubIDs(ClubID VARCHAR(50))

   EXEC procParseStringList @ClubIDList
   INSERT INTO #ClubIDs(ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList


--Replacement cards
INSERT INTO #ReplacementCards (ClubName, UniqueMembershipCount, CardCount)
Select 
	c.clubname,	count(distinct m.membershipid),count(m.membershipid)
from 
	vclub c
left join vmembercardhistory mch
	on (mch.clubid = c.clubid
	-- include whole start and end dates; 
	and Convert(Datetime,Convert(Varchar,mch.requestdatetime, 101),101) >= @StartDate
	and Convert(Datetime,Convert(Varchar,mch.requestdatetime, 101),101) < @AdjustedEndDate
	and mch.valmembercardlettertypeid in (1))
left join vmember m
	on mch.memberid = m.memberid
JOIN #ClubIDs #C 
	ON (#C.ClubID = Convert(varchar,C.ClubID) Or #C.ClubID = '0')
where 
	--c.displayuiflag = 1
	mch.ValMemberCardStatusID = 4 -- status 'Processed'
	and mch.ValMemberCardTypeID = 1 -- permanent cards
	and mch.clubid <> 13            --- do not include Corporate Internal "club"
group by c.clubname



--New Memberships
INSERT INTO #NewMemberships (ClubName, UniqueMembershipCount, CardCount)
Select 
	c.clubname,count(distinct m.membershipid),count(m.membershipid)
from 
	vclub c
left join vmembercardhistory mch
	on (mch.clubid = c.clubid
	-- include whole start and end dates; 
	and Convert(Datetime,Convert(Varchar,mch.requestdatetime, 101),101) >= @StartDate
	and Convert(Datetime,Convert(Varchar,mch.requestdatetime, 101),101) < @AdjustedEndDate
	and mch.valmembercardlettertypeid in (0,2))
left join vmember m
	on mch.memberid = m.memberid
JOIN #ClubIDs #C 
	ON (#C.ClubID = Convert(varchar,C.ClubID) Or #C.ClubID = '0')
where 
	--c.displayuiflag = 1
	mch.ValMemberCardStatusID = 4 -- status 'Processed'
	and mch.ValMemberCardTypeID = 1 -- permanent cards
	and mch.clubid <> 13            --- do not include Corporate Internal "club"
group by c.clubname

-- special cards 
INSERT INTO #SpecialCards (ClubName, UniqueMembershipCount , CardCount )
Select 
	case when msc.clubid is null then c.clubname
	     when c.clubid = 13 then msc.clubname else c.clubname end,
	count(distinct m.membershipid),count(m.membershipid)
from 
	vclub c
left join vmembercardhistory mch 
	on mch.clubid = c.clubid
	and Convert(Datetime,Convert(Varchar,mch.requestdatetime, 101),101) >= @StartDate
	and Convert(Datetime,Convert(Varchar,mch.requestdatetime, 101),101) < @AdjustedEndDate
	and ((mch.valmembercardlettertypeid in (3,4,5) and mch.clubid <> 13)
	      or (mch.clubid = 13))
left join vmember m
	on mch.memberid = m.memberid
left join vmembership ms
	on m.membershipid = ms.membershipid
left join vclub msc
	on ms.clubid = msc.clubid
JOIN #ClubIDs #C 
	ON (#C.ClubID = Convert(varchar,C.ClubID) Or #C.ClubID = '0')
	OR (#C.ClubID = msc.ClubID and c.clubid = 13)
group by case when msc.clubid is null then c.clubname
	          when c.clubid = 13 then msc.clubname else c.clubname end



SELECT 
	C.ClubName, C.ClubCode,C.ClubID,
	ISNULL(RC.UniqueMembershipCount,0) AS CardReplacements_Memberships  , 
	ISNULL(RC.CardCount,0) AS CardReplacements_Cards, 
	ISNULL(NM.UniqueMembershipCount,0) AS NewCards_Memberships, 
	ISNULL(NM.CardCount,0) AS NewCards_Cards,
	ISNULL(SC.UniqueMembershipCount,0) AS SpecialCards_Memberships, 
	ISNULL(SC.CardCount,0) AS SpecialCards_Cards,
	ISNULL(SC.UniqueMembershipCount,0) + ISNULL(RC.UniqueMembershipCount,0) + ISNULL(NM.UniqueMembershipCount,0) AS TotalUniqueMemberships,
	ISNULL(SC.CardCount,0) + ISNULL(RC.CardCount,0) + ISNULL(NM.CardCount,0) AS TotalCards,
	@HeaderFulfillmentRequestDateRange as HeaderDateRange,
	@ReportRunDateTime as ReportRunDateTime
FROM #ClubIDs #C 
JOIN vClub C
	ON (#C.ClubID = Convert(varchar,C.ClubID) Or #C.ClubID = '0')
LEFT JOIN #NewMemberships NM 
	ON NM.ClubName = C.ClubName
LEFT  JOIN #ReplacementCards RC 
	ON RC.ClubName = C.ClubName
LEFT JOIN #SpecialCards SC
	ON SC.ClubName = C.ClubName
Order by C.ClubName


DROP TABLE #SpecialCards
DROP TABLE #ReplacementCards 
DROP TABLE #NewMemberships 
DROP TABLE #tmpList
DROP TABLE #ClubIDs

END
