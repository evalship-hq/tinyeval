// tinyeval worker in C#. .NET 10 runs a .cs file directly, so in your eval file:
//   worker dotnet run evals/worker.cs
// For your app, put this loop in a console project that references it, and keep its logs off stdout.
using System.Text;

var stdin = new BufferedStream(Console.OpenStandardInput());
var stdout = Console.OpenStandardOutput(); // unbuffered, so each reply goes out at once
var input = new MemoryStream();
for (int b; (b = stdin.ReadByte()) != -1;)
{
    if (b != 0)
    {
        input.WriteByte((byte)b);
        continue;
    }
    stdout.Write(Encoding.UTF8.GetBytes(Reply(Encoding.UTF8.GetString(input.ToArray())) + "\0"));
    input.SetLength(0);
}

static string Reply(string input) => "You said: " + input; // your app's AI call goes here
