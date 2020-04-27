
-- This procedure returns a recordset containing a list of unique Integers
-- 
-- The input parameter @IntegerList is an empty Integer or a comma separated list of
-- Integers. If empty it will return an empty recordset
--
-- It will ignore fields in the list that are empty and return nothing for them
--
-- 20040325 Kevin Sigl: changed it to die on non numeric fields rather than
--          ignore them (would rather error than silently ignore things)

CREATE   PROCEDURE [dbo].[procParseIntegerList]
  @IntegerList VARCHAR(8000) = ''
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @tmpInteger VARCHAR(50)
DECLARE @strstart INT
DECLARE @strend INT
DECLARE @nextdelimiter INT
DECLARE @delimiter VARCHAR(5)

SET @delimiter = '|'
SET @strstart = 1
SET @strend = 0


--CREATE TABLE #tmp_procParseInteger (IntegerField INT)

WHILE @strstart <= LEN(@IntegerList)
BEGIN
  SET @nextdelimiter = CHARINDEX(@delimiter, SUBSTRING(@IntegerList, @strstart, LEN(@IntegerList)))

  -- if charindex returned zero the rest of the Integer has no comma and is one field
  IF @nextdelimiter = 0
    SET @strend = LEN(@IntegerList) + 1
  ELSE
    SET @strend = @strstart + @nextdelimiter - 1

  SET @tmpInteger = LTRIM(RTRIM(SUBSTRING(@IntegerList, @strstart, @strend - @strstart)))

  IF @tmpInteger <> '' -- AND ISNUMERIC(@tmpInteger) <> 0
    INSERT INTO #tmpList (StringField) VALUES (CAST(CAST(@tmpInteger as MONEY) as INT))

  -- The beginning of the next Integer is the end plus the comma
  SET @strstart = @strend + 1
END

END
