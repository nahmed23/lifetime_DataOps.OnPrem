


CREATE PROCEDURE procParseClubIDs
  @ClubIDList VARCHAR(1000)
  AS

-- This procedure assumes there is a temp table called #ClubID
-- defined as follows: CREATE TABLE #ClubID(ClubID VARCHAR(15))
-- The input parameter @ClubIDList is an empty string or a comma separated list of
-- ClubIDs separated by commas with no spaces.  The last ClubID is
-- also followed by a comma.

BEGIN
  DECLARE @CommaPosition INT
  IF LTRIM(RTRIM(@ClubIDList)) = ''
  BEGIN
     INSERT INTO #ClubID (ClubID)
     SELECT ClubID FROM vClub WHERE DisplayUIFlag = 1
  END
  ELSE
  BEGIN
    WHILE @ClubIDList <> ''
      BEGIN
        SET @CommaPosition = CHARINDEX(',', @ClubIDList)
        INSERT INTO #ClubID (ClubID) SELECT SUBSTRING(@ClubIDList, 1, @CommaPosition - 1)
        SET @ClubIDList = SUBSTRING(@ClubIDList, @CommaPosition + 1, LEN(@ClubIDList) - @CommaPosition)
      END
  END
  
END
