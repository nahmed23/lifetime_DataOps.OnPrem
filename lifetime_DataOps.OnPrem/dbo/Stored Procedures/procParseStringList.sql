



-- This procedure returns a recordset containing a list of unique strings
-- This procedure assumes that a temp table #tmpList was created by the caller.
-- The input parameter @StringList is an empty string or a comma separated list of
-- strings. If empty it will return an empty recordset
--
-- It will ignore fields in the list that are empty and return nothing for them

CREATE  PROCEDURE [dbo].[procParseStringList]
  @StringList VARCHAR(8000) = ''
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @tmpString VARCHAR(50)
DECLARE @strstart INT
DECLARE @strend INT
DECLARE @nextdelimiter INT
DECLARE @delimiter VARCHAR(5)

SET @delimiter = '|'
SET @strstart = 1
SET @strend = 0
 

--CREATE TABLE #tmpList (StringField VARCHAR(50))

WHILE @strstart <= LEN(@StringList)
BEGIN
  SET @nextdelimiter = CHARINDEX(@delimiter, SUBSTRING(@StringList, @strstart, LEN(@StringList)))

  -- if charindex returned zero the rest of the string has no comma and is one field
  IF @nextdelimiter = 0
    SET @strend = LEN(@StringList) + 1
  ELSE
    SET @strend = @strstart + @nextdelimiter - 1

  SET @tmpString = LTRIM(RTRIM(SUBSTRING(@StringList, @strstart, @strend - @strstart)))

  IF @tmpString <> ''
    INSERT INTO #tmpList (StringField) VALUES (@tmpString)

  -- The beginning of the next string is the end plus the comma
  SET @strstart = @strend + 1
END


END

