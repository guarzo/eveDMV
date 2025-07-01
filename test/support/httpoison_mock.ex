# HTTPoison mock for testing
import Mox

# Define HTTPoison mock for SSE producer testing
Mox.defmock(HTTPoisonMock, for: HTTPoison.Base)
