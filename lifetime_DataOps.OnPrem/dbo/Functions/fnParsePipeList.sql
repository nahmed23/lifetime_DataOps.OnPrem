
CREATE FUNCTION [dbo].[fnParsePipeList] (@List VARCHAR(4096))
RETURNS @Output TABLE
        ( Sequence INT IDENTITY(1,1),
          Item VARCHAR(4096) )
AS
BEGIN
DECLARE @Pointer int 
SET @Pointer = 0
WHILE (LEN(@List) > 0) 
BEGIN 
SET @Pointer = CHARINDEX('|', @List) 
IF (@Pointer = 0) AND (LEN(@List) > 0) 
  BEGIN 
    INSERT @Output VALUES (@List)
    BREAK 
  END 
IF (@Pointer > 1) 
  BEGIN 
    INSERT @Output VALUES (LEFT(@List, @Pointer - 1)) 
    SET @List = RIGHT(@List, (LEN(@List) - @Pointer)) 
  END 
ELSE 
  SET @List = RIGHT(@List, (LEN(@List) - @Pointer)) 
END
RETURN
END

