using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace LWAppNet {
    public partial class Form1 : Form {
        public Form1() {
            InitializeComponent();

            textBox1.Text = "Dir: " + Environment.CurrentDirectory 
                + "\r\nArgs: " + Environment.CommandLine;

        }

        private void textBox1_TextChanged(object sender, EventArgs e) {

        }
    }
}
