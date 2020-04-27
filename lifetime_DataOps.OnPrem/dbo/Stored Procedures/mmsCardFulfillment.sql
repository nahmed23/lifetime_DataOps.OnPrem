

-- exec dbo.mmsCardFulfillment '10', '09/01/09', '09/26/09'
-- exec dbo.mmsCardFulfillment '8|151', '02/01/09', '09/01/09'

CREATE PROCEDURE [dbo].[mmsCardFulfillment] (
  @ClubIDList VARCHAR(1000),
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME
)
AS
BEGIN

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY


CREATE TABLE #SpecialCards (ClubName varchar(50), UniqueMembershipCount INT, CardCount INT)
CREATE TABLE #ReplacementCards (ClubName varchar(50), UniqueMembershipCount INT, CardCount INT)
CREATE TABLE #NewMemberships (ClubName varchar(50), UniqueMembershipCount INT, CardCount INT)

-- list of clubs 
CREATE TABLE #tmpList(StringField VARCHAR(50))
CREATE TABLE #ClubIDs(ClubID INT)
IF @ClubIDList <> '0'
  BEGIN
   EXEC procParseIntegerList @ClubIDList
   INSERT INTO #ClubIDs(ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
  END
ELSE
  BEGIN
   INSERT INTO #ClubIDs Values(0)
  END


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
	and Convert(Datetime,Convert(Varchar,mch.requestdatetime, 101),101) <= @EndDate
	and mch.valmembercardlettertypeid in (1))
left join vmember m
	on mch.memberid = m.memberid
JOIN #ClubIDs #C 
	ON #C.ClubID = C.ClubID
where 
	--c.displayuiflag = 1
	mch.ValMemberCardStatusID = 4 -- status 'Processed'
	and mch.ValMemberCardTypeID = 1 -- permanent cards
	and mch.clubid <> 13 --new 9/19/2011 BSD
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
	and Convert(Datetime,Convert(Varchar,mch.requestdatetime, 101),101) <= @EndDate
	and mch.valmembercardlettertypeid in (0,2))
left join vmember m
	on mch.memberid = m.memberid
JOIN #ClubIDs #C 
	ON #C.ClubID = C.ClubID
where 
	--c.displayuiflag = 1
	mch.ValMemberCardStatusID = 4 -- status 'Processed'
	and mch.ValMemberCardTypeID = 1 -- permanent cards
	and mch.clubid <> 13 --new 9/19/2011 BSD
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
	and Convert(Datetime,Convert(Varchar,mch.requestdatetime, 101),101) <= @EndDate
	and ((mch.valmembercardlettertypeid in (3,4,5) and mch.clubid <> 13)
	      or (mch.clubid = 13))
left join vmember m
	on mch.memberid = m.memberid
left join vmembership ms
	on m.membershipid = ms.membershipid
left join vclub msc
	on ms.clubid = msc.clubid
JOIN #ClubIDs #C 
	ON #C.ClubID = C.ClubID
	OR (#C.ClubID = msc.ClubID and c.clubid = 13)
group by case when msc.clubid is null then c.clubname
	          when c.clubid = 13 then msc.clubname else c.clubname end



SELECT 
	C.ClubName, 
	ISNULL(RC.UniqueMembershipCount,0) AS CardReplacements_Memberships  , 
	ISNULL(RC.CardCount,0) AS CardReplacements_Cards, 
	ISNULL(NM.UniqueMembershipCount,0) AS NewCards_Memberships, 
	ISNULL(NM.CardCount,0) AS NewCards_Cards,
	ISNULL(SC.UniqueMembershipCount,0) AS SpecialCards_Memberships, 
	ISNULL(SC.CardCount,0) AS SpecialCards_Cards,
	ISNULL(SC.UniqueMembershipCount,0) + ISNULL(RC.UniqueMembershipCount,0) + ISNULL(NM.UniqueMembershipCount,0) AS TotalUniqueMemberships,
	ISNULL(SC.CardCount,0) + ISNULL(RC.CardCount,0) + ISNULL(NM.CardCount,0) AS TotalCards 
FROM #ClubIDs #C 
JOIN vClub c
	ON #C.ClubID = C.ClubID
LEFT JOIN #NewMemberships NM 
	ON NM.ClubName = C.ClubName
LEFT  JOIN #ReplacementCards RC 
	ON RC.ClubName = C.ClubName
LEFT JOIN #SpecialCards SC
	ON SC.ClubName = C.ClubName


DROP TABLE #SpecialCards
DROP TABLE #ReplacementCards 
DROP TABLE #NewMemberships 
DROP TABLE #tmpList
DROP TABLE #ClubIDs

 -- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END


