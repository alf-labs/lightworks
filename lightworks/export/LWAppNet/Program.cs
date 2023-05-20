using System;
using System.Diagnostics;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace LWAppNet {
    static class Program {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main() {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            String bat = Environment.CommandLine.Replace(".exe", ".bat");

            int exitCode = 0;
            String err = "";
            try {
                Process p = Process.Start("cmd", "/c " + bat);
                p.WaitForExit();
                exitCode = p.ExitCode;
                p.Close();

            } catch (Exception e) {
                err = e.ToString();
            }
            if (exitCode != 0 || err != "") {
                MessageBox.Show("ExitCode: " + exitCode + ".\r\n" + err, "Exec " + bat);
            }
        }
    }
}
