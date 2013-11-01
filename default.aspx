<%@ Page Language="c#" EnableViewState="true" AutoEventWireup="true" ValidateRequest="false" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>
<%@ Import Namespace="System.Globalization" %>
<%@ Import Namespace="System.Threading" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Collections" %>

<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset-utf=8" />
	<meta http-equiv="Content-language" content="cs" />
	<meta http-equiv="pragma" content="no-cache" />
	<meta http-equiv="cache-control" content="private" />
	<title>SQL Console</title>
</head>
<body>
	<form method="post" runat="server">
		<label>
			<span>Connection String:</span>
			<input type="text" size="60" id="inConn" runat="server" />
		</label>
		<br />
		
		<textarea style="width: 90%; height: 200px" id="inQuery" runat="server"></textarea>
		<br />

		<input type="submit" value="RUN!" id="btnExec" runat="server" onserverclick="btnExec_ServerClick" />

		<asp:DropDownList id="inType" AutoPostBack="true" OnSelectedIndexChanged="inType_SelectedIndexChanged" runat="server">
			<asp:ListItem>Select</asp:ListItem>
			<asp:ListItem>Insert</asp:ListItem>
			<asp:ListItem>Update</asp:ListItem>
		</asp:DropDownList>

		<label>
			<span>Table</span>
			<input type="text" name="style" id="inInserts" size="10" runat="server" value="{TABLE}" />
		</label>

		<label>
			<span>ID Column</span>
			<input type="text" name="style" id="inUpdates" size="10" runat="server" value="{ID}" />
		</label>
		
	</form>

	<div runat="server" id="inOutput" style="text-align: left" enableviewstate="false"></div>
</body>
</html>

<script runat="server">

	private string CONN_CONSOLE = "";
	private enum Types { Select, Insert, Update };

	private void Page_Load(object sender, EventArgs e)
	{
		if (inConn.Value.Trim().Length > 5)
			CONN_CONSOLE = inConn.Value;
	}

	void inType_SelectedIndexChanged(object sender, EventArgs e)
	{
		if (Types.Insert.ToString().Equals(inType.SelectedValue))
			Response.Write(inType.SelectedValue);
	}

	private void btnExec_ServerClick(object sender, EventArgs e)
	{
		if (inQuery == null || inOutput == null)
			return;
		
		Thread.CurrentThread.CurrentCulture = new CultureInfo("en-us");
		
		string query = Server.HtmlDecode(inQuery.Value.Trim());
		string[] commands = Regex.Split(query, @"\n\s*GO\s*\n", RegexOptions.IgnoreCase);
		
		if (commands.Length == 0 || String.IsNullOrEmpty(CONN_CONSOLE))
			return;
		
		using (SqlConnection conn = new SqlConnection(CONN_CONSOLE))
		{
			StringBuilder result = new StringBuilder();
			try
			{
				conn.Open();
				foreach (string command in commands)
				{
					if (command.Length <= 2)
						continue;
					if (Types.Select.Equals(inType.SelectedValue))
						result.AppendFormat("\n<i><pre>{0}</pre></i>\n<hr />{1}<hr />\n", Server.HtmlEncode(command), ExecuteCommand(command, conn));
					if (Types.Insert.Equals(inType.SelectedValue))
						result.AppendFormat("\n{0}<hr />\n", MakeInserts(command, conn));
					if (Types.Update.Equals(inType.SelectedValue))
						result.AppendFormat("\n{0}<hr />\n", MakeUpdates(command, conn));
				}
				inOutput.InnerHtml = result.ToString();
			}
			catch (Exception exc)
			{
				inOutput.InnerHtml = string.Format("<span style=\"color:red\">ERROR: {0}</span>", exc.ToString());
			}
		}
	}

	private string ExecuteCommand(string command, SqlConnection conn)
	{
		StringBuilder result = new StringBuilder();
		SqlCommand cmd = new SqlCommand(command, conn);
		try
		{
			using (SqlDataReader dr = cmd.ExecuteReader())
			{
				do
				{
					result.Append("\n<table border=\"1\"><tr>");
					for (int i = 0; i < dr.FieldCount; i++)
						result.AppendFormat("\n<td><b>{0}</b></td>", dr.GetName(i));
					result.Append("\n</tr>");
					while (dr.Read())
					{
						result.Append("\n<tr>");
						for (int i = 0; i < dr.FieldCount; i++)
							result.AppendFormat("\n<td><pre>{0}</pre></td>", GetValue(dr[i], false));
						result.Append("\n</tr>");
					}
					result.Append("\n</table>");
				}
				while (dr.NextResult());
			}
			result.Append("Command executed succesfully!");
		}
		catch (Exception exc)
		{
			result.AppendFormat("<span style=\"color:red\">ERROR: {0}</span>", exc.ToString());
		}
		return result.ToString();
	}


	private string MakeInserts(string command, SqlConnection conn)
	{
		StringBuilder result = new StringBuilder();
		SqlCommand cmd = new SqlCommand(command, conn);
		try
		{
			using (SqlDataReader dr = cmd.ExecuteReader())
			{
				do
				{
					result.AppendFormat("\n<table border=\"1\"><tr>\n<td><b>{0}</b></td>\n</tr><tr><td><pre>", command);
					bool baseInsert = (inInserts == null || inInserts.Value == "" || inInserts.Value == "{ID}");

					if (baseInsert)
						result.AppendFormat("SET IDENTITY_INSERT {TABLE} ON;\n\n");
					else
						result.AppendFormat("SET IDENTITY_INSERT {0} ON;\n\n", inInserts.Value);

					while (dr.Read())
					{
						if (baseInsert)
							result.Append("\nINSERT INTO {TABLE} (");
						else
							result.AppendFormat("\nINSERT INTO {0} (", inInserts.Value);

						for (int i = 0; i < dr.FieldCount; i++)
						{
							if (i > 0)
								result.Append(", ");
							result.AppendFormat("{0}", dr.GetName(i) == "" ? "{COL}" : dr.GetName(i));
						}

						result.Append(")\n\tVALUES (");

						for (int i = 0; i < dr.FieldCount; i++)
						{
							if (i > 0)
								result.Append(", ");
							result.Append(GetValue(dr[i], true));
						}

						result.Append(");\n");
					}

					result.Append("\n");

					if (baseInsert)
						result.AppendFormat("SET IDENTITY_INSERT {TABLE} OFF;\n");
					else
						result.AppendFormat("SET IDENTITY_INSERT {0} OFF;\n", inInserts.Value);

					result.Append("\n</pre></td></tr></table>");
				}
				while (dr.NextResult());
			}
			result.Append("Command executed succesfully!");
		}
		catch (Exception exc)
		{
			result.AppendFormat("<span style=\"color:red\">ERROR: {0}</span>", exc.ToString());
		}

		return result.ToString();
	}


	private string MakeUpdates(string command, SqlConnection conn)
	{
		StringBuilder result = new StringBuilder();
		SqlCommand cmd = new SqlCommand(command, conn);
		try
		{
			using (SqlDataReader dr = cmd.ExecuteReader())
			{
				do
				{
					result.AppendFormat("\n<table border=\"1\"><tr>\n<td><b>{0}</b></td>\n</tr><tr><td><pre>", command);
					bool baseUpdate = (inInserts == null || inInserts.Value == "" || inInserts.Value == "{ID}");
					while (dr.Read())
					{
						if (baseUpdate)
							result.Append("\nUPDATE {TABLE} SET ");
						else
							result.AppendFormat("\nUPDATE {0} SET ", inInserts.Value);

						for (int i = 0; i < dr.FieldCount; i++)
						{
							if (i > 0)
								result.Append(", ");
							result.AppendFormat("{0}={1}", dr.GetName(i) == "" ? "{COL}" : dr.GetName(i), GetValue(dr[i], true));
						}

						if (baseUpdate)
							result.Append("\n\tWHERE {COLUMN}={ID};\n");
						else
							result.AppendFormat("\n\tWHERE {0}={1};\n", inUpdates.Value, GetValue(dr[inUpdates.Value], true));
					}
					result.Append("\n</pre></td></tr></table>");
				}
				while (dr.NextResult());
			}
			result.Append("Command executed succesfully!");
		}
		catch (Exception exc)
		{
			result.AppendFormat("<span style=\"color:red\">ERROR: {0}</span>", exc.ToString());
		}
		return result.ToString();
	}


	private string GetValue(object obj, bool replace)
	{
		switch (obj.GetType().FullName)
		{
			case "System.Int16":
			case "System.UInt16":
			case "System.Int32":
			case "System.UInt32":
			case "System.Int64":
			case "System.UInt64":
			case "System.Byte":
			case "System.SByte":
			case "System.Single":
			case "System.Double":
			case "System.Decimal":
				return string.Format("{0:G}", obj);
			case "System.DBNull":
				return "NULL";
			case "System.String":
			case "System.Char":
				return string.Format("'{0}'", Normalize(obj, replace));
			case "System.DateTime":
				return string.Format("'{0:s}'", obj);
			case "System.Boolean":
				return (bool)obj ? "1" : "0";
			default:
				return string.Format("'{0}'", Normalize(obj, replace));
		}
	}

	private string Normalize(object obj, bool replace)
	{
		string s = Server.HtmlEncode(obj.ToString());
		return replace ? s.Replace("'", "''") : s;
	}


</script>

