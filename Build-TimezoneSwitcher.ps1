$ProjectName = "TimezoneSwitcher"
$TargetDir = Join-Path -Path $PSScriptRoot -ChildPath $ProjectName

# Step 0: Fix corrupted NuGet.Config if present
$NugetConfigPath = "$env:APPDATA\NuGet\NuGet.Config"
Write-Host "[0/5] Checking NuGet configuration..." -ForegroundColor Cyan

$NeedsRepair = $false
if (-not (Test-Path $NugetConfigPath)) {
    $NeedsRepair = $true
} else {
    $Content = Get-Content -Path $NugetConfigPath -Raw
    if ([string]::IsNullOrWhiteSpace($Content)) {
        $NeedsRepair = $true
    }
}

if ($NeedsRepair) {
    Write-Host "  -> Repairing corrupted/missing NuGet.Config..." -ForegroundColor Yellow
    $ValidNugetXml = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
  </packageSources>
</configuration>
"@
    New-Item -ItemType Directory -Path (Split-Path $NugetConfigPath) -Force | Out-Null
    Set-Content -Path $NugetConfigPath -Value $ValidNugetXml -Encoding UTF8
}

Write-Host "[1/5] Setting up project directory at: $TargetDir" -ForegroundColor Cyan
if (Test-Path $TargetDir) {
    Remove-Item -Path $TargetDir -Recurse -Force
}
New-Item -ItemType Directory -Path $TargetDir | Out-Null

# Handle app.ico resource embedding
$IconSourcePath = Join-Path -Path $PSScriptRoot -ChildPath "app.ico"
$IconTargetPath = Join-Path -Path $TargetDir -ChildPath "app.ico"

if (Test-Path $IconSourcePath) {
    Copy-Item -Path $IconSourcePath -Destination $IconTargetPath -Force
} else {
    $DummyIcoBytes = [byte[]]@(
        0,0, 1,0, 1,0, 16,16, 0,0, 1,0, 32,0, 68,0,0,0, 22,0,0,0,
        40,0,0,0, 16,0,0,0, 32,0,0,0, 1,0, 32,0, 0,0,0,0, 0,0,0,0,
        0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
    ) + [byte[]]::new(1024)
    [System.IO.File]::WriteAllBytes($IconTargetPath, $DummyIcoBytes)
}

$CsprojContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net10.0-windows</TargetFramework>
    <ApplicationIcon>app.ico</ApplicationIcon>
    <UseWPF>true</UseWPF>
    <RootNamespace>$ProjectName</RootNamespace>
    <ApplicationManifest>app.manifest</ApplicationManifest>
    <Platforms>x64</Platforms>
    <RuntimeIdentifiers>win-x64</RuntimeIdentifiers>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <PublishTrimmed>false</PublishTrimmed>
    <PublishSingleFile>true</PublishSingleFile>
    <SelfContained>true</SelfContained>
    <IncludeNativeLibrariesForSelfExtract>true</IncludeNativeLibrariesForSelfExtract>
    <EnableCompressionInSingleFile>true</EnableCompressionInSingleFile>
  </PropertyGroup>

  <ItemGroup>
    <Resource Include="app.ico" />
    <PackageReference Include="CommunityToolkit.Mvvm" Version="8.2.2" />
  </ItemGroup>
</Project>
"@

$AppXamlContent = @"
<Application x:Class="$ProjectName.App"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             StartupUri="MainWindow.xaml">
    <Application.Resources>
        <SolidColorBrush x:Key="WindowBackgroundBrush" Color="#CC0E131F" />
        <SolidColorBrush x:Key="HeaderBackgroundBrush" Color="#EE131927" />
        <SolidColorBrush x:Key="CardBackgroundBrush" Color="#DD131927" />
        <SolidColorBrush x:Key="PrimaryTextBrush" Color="#FFFFFF" />
        <SolidColorBrush x:Key="SecondaryTextBrush" Color="#8B9BB4" />
        <SolidColorBrush x:Key="MutedTextBrush" Color="#6C7C96" />
        <SolidColorBrush x:Key="BorderBrush" Color="#1C2436" />
        <SolidColorBrush x:Key="InputBackgroundBrush" Color="#EE182033" />
        <SolidColorBrush x:Key="AccentBrush" Color="#4C8EFF" />
    </Application.Resources>
</Application>
"@

$AppCsContent = @"
using System;
using System.IO;
using System.Windows;
using System.Windows.Media;

namespace $ProjectName
{
    public partial class App : Application
    {
        public static bool IsLoggingEnabled { get; set; } = true;
        public static string CurrentTheme { get; private set; } = "Dark";
        public static double WindowOpacityLevel { get; set; } = 0.80; // Default 80%
        public static event Action<string>? ThemeChanged;
        public static event Action<double>? OpacityChanged;

        private static readonly string LogDirPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "log");
        private static readonly string LogFilePath = Path.Combine(LogDirPath, "app.log");

        protected override void OnStartup(StartupEventArgs e)
        {
            DispatcherUnhandledException += App_DispatcherUnhandledException;
            AppDomain.CurrentDomain.UnhandledException += CurrentDomain_UnhandledException;

            Log("================ Application Started ================");
            base.OnStartup(e);
        }

        public static void SetWindowOpacity(double opacity)
        {
            WindowOpacityLevel = opacity;
            UpdateBrushOpacity("WindowBackgroundBrush", opacity);
            OpacityChanged?.Invoke(opacity);
        }

        public static void SetTheme(string themeName)
        {
            CurrentTheme = themeName;
            switch (themeName)
            {
                case "Light":
                    UpdateBrush("WindowBackgroundBrush", "#F4F5F7");
                    UpdateBrush("HeaderBackgroundBrush", "#EEFFFFFF");
                    UpdateBrush("CardBackgroundBrush", "#EEFFFFFF");
                    UpdateBrush("PrimaryTextBrush", "#1E293B");
                    UpdateBrush("SecondaryTextBrush", "#475569");
                    UpdateBrush("MutedTextBrush", "#64748B");
                    UpdateBrush("BorderBrush", "#CBD5E1");
                    UpdateBrush("InputBackgroundBrush", "#EEE2E8F0");
                    UpdateBrush("AccentBrush", "#2563EB");
                    break;

                case "Win95":
                    UpdateBrush("WindowBackgroundBrush", "#008080");
                    UpdateBrush("HeaderBackgroundBrush", "#FFC0C0C0");
                    UpdateBrush("CardBackgroundBrush", "#FFC0C0C0");
                    UpdateBrush("PrimaryTextBrush", "#000000");
                    UpdateBrush("SecondaryTextBrush", "#000080");
                    UpdateBrush("MutedTextBrush", "#404040");
                    UpdateBrush("BorderBrush", "#808080");
                    UpdateBrush("InputBackgroundBrush", "#FFFFFFFF");
                    UpdateBrush("AccentBrush", "#000080");
                    break;

                case "Cyberpunk":
                    UpdateBrush("WindowBackgroundBrush", "#1A092B");
                    UpdateBrush("HeaderBackgroundBrush", "#EE2D124D");
                    UpdateBrush("CardBackgroundBrush", "#EE2D124D");
                    UpdateBrush("PrimaryTextBrush", "#00F0FF");
                    UpdateBrush("SecondaryTextBrush", "#FF007F");
                    UpdateBrush("MutedTextBrush", "#FFE600");
                    UpdateBrush("BorderBrush", "#FF007F");
                    UpdateBrush("InputBackgroundBrush", "#EE3D1A68");
                    UpdateBrush("AccentBrush", "#FF007F");
                    break;

                case "Nord":
                    UpdateBrush("WindowBackgroundBrush", "#2E3440");
                    UpdateBrush("HeaderBackgroundBrush", "#EE3B4252");
                    UpdateBrush("CardBackgroundBrush", "#EE3B4252");
                    UpdateBrush("PrimaryTextBrush", "#ECEFF4");
                    UpdateBrush("SecondaryTextBrush", "#E5E9F0");
                    UpdateBrush("MutedTextBrush", "#D8DEE9");
                    UpdateBrush("BorderBrush", "#4C566A");
                    UpdateBrush("InputBackgroundBrush", "#EE434C5E");
                    UpdateBrush("AccentBrush", "#88C0D0");
                    break;

                default: // Dark
                    UpdateBrush("WindowBackgroundBrush", "#0E131F");
                    UpdateBrush("HeaderBackgroundBrush", "#EE131927");
                    UpdateBrush("CardBackgroundBrush", "#DD131927");
                    UpdateBrush("PrimaryTextBrush", "#FFFFFF");
                    UpdateBrush("SecondaryTextBrush", "#8B9BB4");
                    UpdateBrush("MutedTextBrush", "#6C7C96");
                    UpdateBrush("BorderBrush", "#1C2436");
                    UpdateBrush("InputBackgroundBrush", "#EE182033");
                    UpdateBrush("AccentBrush", "#4C8EFF");
                    break;
            }

            UpdateBrushOpacity("WindowBackgroundBrush", WindowOpacityLevel);
            ThemeChanged?.Invoke(themeName);
        }

        private static void UpdateBrush(string name, string hex)
        {
            var color = (Color)ColorConverter.ConvertFromString(hex);
            Current.Resources[name] = new SolidColorBrush(color);
        }

        private static void UpdateBrushOpacity(string name, double opacity)
        {
            if (Current.Resources[name] is SolidColorBrush brush)
            {
                Color color = brush.Color;
                color.A = (byte)(opacity * 255);
                Current.Resources[name] = new SolidColorBrush(color);
            }
        }

        public static void Log(string message)
        {
            if (!IsLoggingEnabled) return;

            try
            {
                if (!Directory.Exists(LogDirPath)) Directory.CreateDirectory(LogDirPath);
                string logEntry = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}] {message}{Environment.NewLine}";
                File.AppendAllText(LogFilePath, logEntry);
            }
            catch { }
        }

        private void App_DispatcherUnhandledException(object sender, System.Windows.Threading.DispatcherUnhandledExceptionEventArgs e)
        {
            Log($"CRITICAL UI EXCEPTION: {e.Exception}");
            MessageBox.Show($"An error occurred:\n{e.Exception.Message}\n\nCheck ./log/app.log for details.", 
                            "Timezone Switcher Error", MessageBoxButton.OK, MessageBoxImage.Error);
            e.Handled = true;
        }

        private void CurrentDomain_UnhandledException(object sender, UnhandledExceptionEventArgs e)
        {
            if (e.ExceptionObject is Exception ex)
            {
                Log($"CRITICAL DOMAIN EXCEPTION: {ex}");
            }
        }
    }
}
"@

$MainWindowXamlContent = @"
<Window x:Class="$ProjectName.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Timezone Switcher" Height="700" Width="500"
        Icon="app.ico"
        WindowStartupLocation="CenterScreen"
        AllowsTransparency="True"
        WindowStyle="None"
        Background="Transparent"
        Foreground="{DynamicResource PrimaryTextBrush}"
        Closing="Window_Closing">

    <Border CornerRadius="12" Background="{DynamicResource WindowBackgroundBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" ClipToBounds="True">
        <Grid Margin="0">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- BACKGROUND ANIMATION LAYERS -->
            <!-- Layer 1: Ambient Mesh Glow (Fast Breathing & Motion) -->
            <Canvas x:Name="AmbientMeshCanvas" Grid.RowSpan="3" IsHitTestVisible="False" Visibility="Visible">
                <Ellipse x:Name="GlowOrb1" Width="300" Height="300" Canvas.Left="-50" Canvas.Top="-50" Opacity="0.4">
                    <Ellipse.RenderTransform>
                        <TransformGroup>
                            <ScaleTransform x:Name="Orb1Scale" CenterX="150" CenterY="150"/>
                            <TranslateTransform x:Name="Orb1Translate"/>
                        </TransformGroup>
                    </Ellipse.RenderTransform>
                    <Ellipse.Fill>
                        <RadialGradientBrush>
                            <GradientStop Color="#4C8EFF" Offset="0"/>
                            <GradientStop Color="#00000000" Offset="1"/>
                        </RadialGradientBrush>
                    </Ellipse.Fill>
                </Ellipse>
                <Ellipse x:Name="GlowOrb2" Width="320" Height="320" Canvas.Right="-60" Canvas.Bottom="-40" Opacity="0.3">
                    <Ellipse.RenderTransform>
                        <TransformGroup>
                            <ScaleTransform x:Name="Orb2Scale" CenterX="160" CenterY="160"/>
                            <TranslateTransform x:Name="Orb2Translate"/>
                        </TransformGroup>
                    </Ellipse.RenderTransform>
                    <Ellipse.Fill>
                        <RadialGradientBrush>
                            <GradientStop Color="#9055FF" Offset="0"/>
                            <GradientStop Color="#00000000" Offset="1"/>
                        </RadialGradientBrush>
                    </Ellipse.Fill>
                </Ellipse>
            </Canvas>

            <!-- Layer 2: Particle Network Canvas (Interconnected Nodes) -->
            <Canvas x:Name="ParticleCanvas" Grid.RowSpan="3" IsHitTestVisible="False" Visibility="Collapsed"/>

            <!-- Custom Header / Window Title Bar -->
            <Border x:Name="HeaderBorder" Grid.Row="0" Background="{DynamicResource HeaderBackgroundBrush}" Padding="16,10" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="0,0,0,1" MouseDown="Header_MouseDown">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock Text="Timezone Switcher" FontSize="18" FontWeight="Bold" Foreground="{DynamicResource PrimaryTextBrush}"/>
                        <TextBlock Text="Quick-switch for US market hours" FontSize="11" Foreground="{DynamicResource SecondaryTextBrush}" Margin="0,2,0,0"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="BtnSettings" Content="⚙" Click="BtnSettings_Click" Width="26" Height="26" Background="Transparent" Foreground="{DynamicResource SecondaryTextBrush}" BorderThickness="0" FontSize="15" Cursor="Hand"/>
                        <Button x:Name="BtnPin" Content="📌" Click="BtnPin_Click" Width="26" Height="26" Background="Transparent" Foreground="{DynamicResource SecondaryTextBrush}" BorderThickness="0" FontSize="13" Cursor="Hand" Margin="2,0,0,0"/>
                        <Button x:Name="BtnMinimize" Content="─" Click="BtnMinimize_Click" Width="26" Height="26" Background="Transparent" Foreground="{DynamicResource SecondaryTextBrush}" BorderThickness="0" FontSize="12" Cursor="Hand" Margin="2,0,0,0"/>
                        <Button x:Name="BtnClose" Content="✕" Click="BtnClose_Click" Width="26" Height="26" Background="Transparent" Foreground="#FF5555" BorderThickness="0" FontSize="13" FontWeight="Bold" Cursor="Hand" Margin="2,0,0,0"/>
                    </StackPanel>
                </Grid>
            </Border>

            <!-- Main Content -->
            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                <Border Padding="14,10">
                    <StackPanel>
                        
                        <!-- Current Zone Status Banner -->
                        <Border x:Name="BannerBorder" Background="{DynamicResource CardBackgroundBrush}" CornerRadius="6" Padding="10,6" Margin="0,0,0,12" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1">
                            <StackPanel Orientation="Horizontal">
                                <!-- Pulse Dot Container -->
                                <Grid Width="14" Height="14" Margin="0,0,8,0" VerticalAlignment="Center">
                                    <Ellipse x:Name="PulseRing" Width="12" Height="12" Fill="{DynamicResource AccentBrush}" Opacity="0.6" HorizontalAlignment="Center" VerticalAlignment="Center">
                                        <Ellipse.RenderTransform>
                                            <ScaleTransform x:Name="PulseScale" CenterX="6" CenterY="6" ScaleX="1" ScaleY="1"/>
                                        </Ellipse.RenderTransform>
                                    </Ellipse>
                                    <Ellipse Width="7" Height="7" Fill="{DynamicResource AccentBrush}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Grid>
                                <TextBlock x:Name="TxtCurrentZoneBanner" Text="Eastern Standard Time" FontSize="12" Foreground="{DynamicResource PrimaryTextBrush}" FontWeight="SemiBold"/>
                            </StackPanel>
                        </Border>

                        <!-- Quick Switch Section -->
                        <TextBlock Text="QUICK SWITCH" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource MutedTextBrush}" Margin="2,0,0,6"/>
                        <Grid Margin="2,0,2,4">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="140"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="95"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="ZONE / CITY" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource MutedTextBrush}"/>
                            <TextBlock Grid.Column="1" Text="LIVE TIME" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource MutedTextBrush}" HorizontalAlignment="Center"/>
                            <TextBlock Grid.Column="2" Text="CONVERTED" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource MutedTextBrush}" HorizontalAlignment="Right"/>
                        </Grid>

                        <ItemsControl x:Name="LstQuickSwitch">
                            <ItemsControl.ItemTemplate>
                                <DataTemplate>
                                    <Border x:Name="CardBorder" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="6" Margin="0,2" Padding="6,4">
                                        <Border.RenderTransform>
                                            <ScaleTransform x:Name="CardScale" CenterX="190" CenterY="16" ScaleX="1" ScaleY="1"/>
                                        </Border.RenderTransform>
                                        <Border.Triggers>
                                            <EventTrigger RoutedEvent="Border.MouseEnter">
                                                <BeginStoryboard>
                                                    <Storyboard>
                                                        <DoubleAnimation Storyboard.TargetName="CardScale" Storyboard.TargetProperty="ScaleX" To="1.02" Duration="0:0:0.15"/>
                                                        <DoubleAnimation Storyboard.TargetName="CardScale" Storyboard.TargetProperty="ScaleY" To="1.02" Duration="0:0:0.15"/>
                                                    </Storyboard>
                                                </BeginStoryboard>
                                            </EventTrigger>
                                            <EventTrigger RoutedEvent="Border.MouseLeave">
                                                <BeginStoryboard>
                                                    <Storyboard>
                                                        <DoubleAnimation Storyboard.TargetName="CardScale" Storyboard.TargetProperty="ScaleX" To="1.0" Duration="0:0:0.15"/>
                                                        <DoubleAnimation Storyboard.TargetName="CardScale" Storyboard.TargetProperty="ScaleY" To="1.0" Duration="0:0:0.15"/>
                                                    </Storyboard>
                                                </BeginStoryboard>
                                            </EventTrigger>
                                        </Border.Triggers>

                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="135"/>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="85"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                                                <Button Content="{Binding ZoneLabel}" 
                                                        Click="BtnSwitchZone_Click" Tag="{Binding ZoneId}"
                                                        Background="{DynamicResource InputBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" FontWeight="Bold" FontSize="11"
                                                        BorderThickness="0" Padding="6,4" HorizontalAlignment="Left" Width="80" Cursor="Hand"/>
                                                <TextBlock Text="{Binding CityName}" FontSize="11" Foreground="{DynamicResource SecondaryTextBrush}" VerticalAlignment="Center" Margin="6,0,0,0"/>
                                            </StackPanel>
                                            <TextBlock Grid.Column="1" Text="{Binding LiveTime}" FontSize="13" FontWeight="Bold" Foreground="{DynamicResource AccentBrush}" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                                            <TextBlock Grid.Column="2" Text="{Binding ConvertedTime}" FontSize="12" Foreground="{DynamicResource SecondaryTextBrush}" VerticalAlignment="Center" HorizontalAlignment="Right"/>
                                        </Grid>
                                    </Border>
                                </DataTemplate>
                            </ItemsControl.ItemTemplate>
                        </ItemsControl>

                        <Separator Background="{DynamicResource BorderBrush}" Margin="0,12"/>

                        <!-- Time Converter Section -->
                        <StackPanel Orientation="Horizontal" Margin="2,0,0,6">
                            <TextBlock Text="⏰ " FontSize="11"/>
                            <TextBlock Text="TIME CONVERTER" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource AccentBrush}"/>
                        </StackPanel>

                        <Grid Margin="0,2,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <!-- Time Inputs -->
                            <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                                <TextBlock Text="Time: " Foreground="{DynamicResource SecondaryTextBrush}" FontSize="11" VerticalAlignment="Center"/>
                                <TextBox x:Name="TxtHour" Text="12" Width="26" Padding="1" Background="{DynamicResource InputBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderBrush="{DynamicResource BorderBrush}" HorizontalContentAlignment="Center"/>
                                <TextBlock Text=" : " Foreground="{DynamicResource SecondaryTextBrush}" FontSize="11" VerticalAlignment="Center"/>
                                <TextBox x:Name="TxtMinute" Text="00" Width="26" Padding="1" Background="{DynamicResource InputBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderBrush="{DynamicResource BorderBrush}" HorizontalContentAlignment="Center"/>
                            </StackPanel>

                            <!-- AM/PM Toggle -->
                            <StackPanel Grid.Column="1" Orientation="Horizontal" Margin="6,0">
                                <RadioButton x:Name="RbAM" Content="AM" IsChecked="True" GroupName="AmPm" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="11" VerticalAlignment="Center" Margin="0,0,4,0"/>
                                <RadioButton x:Name="RbPM" Content="PM" GroupName="AmPm" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="11" VerticalAlignment="Center"/>
                            </StackPanel>

                            <!-- Zone Selector -->
                            <StackPanel Grid.Column="2" Orientation="Horizontal">
                                <TextBlock Text="Zone: " Foreground="{DynamicResource SecondaryTextBrush}" FontSize="11" VerticalAlignment="Center"/>
                                <ComboBox x:Name="CmbConvertZone" HorizontalAlignment="Stretch" Background="{DynamicResource InputBackgroundBrush}" Foreground="#000000" BorderBrush="{DynamicResource BorderBrush}" DisplayMemberPath="DisplayName" SelectedValuePath="Id" FontSize="11"/>
                            </StackPanel>
                        </Grid>

                        <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                            <Button Content="Convert" Click="BtnConvert_Click" Width="80" Padding="5" Background="{DynamicResource AccentBrush}" Foreground="#FFFFFF" FontWeight="Bold" FontSize="11" BorderThickness="0" Cursor="Hand"/>
                            <Button Content="Now" Click="BtnNow_Click" Width="60" Padding="5" Margin="6,0,0,0" Background="{DynamicResource InputBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" FontWeight="Bold" FontSize="11" BorderThickness="0" Cursor="Hand"/>
                        </StackPanel>
                        <TextBlock Text="Converted times appear in the 3rd column above ↑" FontSize="10" Foreground="{DynamicResource MutedTextBrush}" Margin="2,0,0,0"/>

                        <Separator Background="{DynamicResource BorderBrush}" Margin="0,12"/>

                        <!-- Other Zones Section -->
                        <TextBlock Text="OTHER ZONES" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource MutedTextBrush}" Margin="2,0,0,6"/>
                        <ComboBox x:Name="CmbAllZones" Background="{DynamicResource InputBackgroundBrush}" Foreground="#000000" BorderBrush="{DynamicResource BorderBrush}" Padding="6" DisplayMemberPath="DisplayName" SelectedValuePath="Id" FontSize="11" Margin="0,0,0,6"/>
                        <Button Content="Switch to Selected" Click="BtnSwitchCustom_Click" Padding="8" Background="{DynamicResource AccentBrush}" Foreground="#FFFFFF" FontWeight="Bold" FontSize="11" BorderThickness="0" Cursor="Hand"/>

                    </StackPanel>
                </Border>
            </ScrollViewer>

            <!-- Footer -->
            <Border x:Name="FooterBorder" Grid.Row="2" Background="{DynamicResource HeaderBackgroundBrush}" Padding="14,10" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="0,1,0,0">
                <StackPanel>
                    <TextBlock x:Name="TxtOriginalZone" Text="Original: Fetching..." FontSize="10" Foreground="{DynamicResource SecondaryTextBrush}"/>
                    <TextBlock Text="Auto-reverts to original timezone on close" FontSize="10" Foreground="#4EAB62" FontWeight="SemiBold" Margin="0,1,0,0"/>
                </StackPanel>
            </Border>
        </Grid>
    </Border>
</Window>
"@

$MainWindowCsContent = @"
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using System.Windows.Threading;

namespace $ProjectName
{
    public class QuickZoneItem : INotifyPropertyChanged
    {
        public string ZoneLabel { get; set; } = string.Empty;
        public string CityName { get; set; } = string.Empty;
        public string ZoneId { get; set; } = string.Empty;

        private string _liveTime = string.Empty;
        public string LiveTime
        {
            get => _liveTime;
            set { _liveTime = value; OnPropertyChanged(nameof(LiveTime)); }
        }

        private string _convertedTime = string.Empty;
        public string ConvertedTime
        {
            get => _convertedTime;
            set { _convertedTime = value; OnPropertyChanged(nameof(ConvertedTime)); }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged(string name) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }

    public class Particle
    {
        public double X { get; set; }
        public double Y { get; set; }
        public double VX { get; set; }
        public double VY { get; set; }
        public Ellipse Element { get; set; } = null!;
    }

    public partial class MainWindow : Window
    {
        private readonly string _initialSystemZoneId;
        private readonly DispatcherTimer _timer = new DispatcherTimer();
        private readonly DispatcherTimer _particleTimer = new DispatcherTimer();
        private readonly List<Particle> _particles = new List<Particle>();
        private readonly List<Line> _connectionLines = new List<Line>();
        private readonly Random _rand = new Random();

        public ObservableCollection<QuickZoneItem> QuickZones { get; set; } = new ObservableCollection<QuickZoneItem>();
        public bool ShowSeconds { get; set; } = true;
        public bool ShowDayOfWeek { get; set; } = true;

        public MainWindow()
        {
            InitializeComponent();

            App.Log("Initializing MainWindow...");
            _initialSystemZoneId = TimeZoneInfo.Local.Id;
            App.Log($"Detected original system timezone ID: {_initialSystemZoneId}");

            TxtOriginalZone.Text = $"Original: {TimeZoneInfo.Local.DisplayName}";

            InitQuickZones();
            InitDropdowns();
            InitAnimations();

            App.ThemeChanged += OnThemeChanged;
            ApplyThemeVisuals(App.CurrentTheme);

            _timer.Interval = TimeSpan.FromSeconds(1);
            _timer.Tick += Timer_Tick;
            _timer.Start();

            UpdateLiveTimes();
            App.Log("MainWindow Initialized successfully.");
        }

        private void Header_MouseDown(object sender, MouseButtonEventArgs e)
        {
            if (e.ChangedButton == MouseButton.Left)
            {
                this.DragMove();
            }
        }

        private void BtnMinimize_Click(object sender, RoutedEventArgs e)
        {
            this.WindowState = WindowState.Minimized;
        }

        private void BtnClose_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }

        private void InitQuickZones()
        {
            QuickZones.Add(new QuickZoneItem { ZoneLabel = "EEST", CityName = "Cairo", ZoneId = "E. Europe Standard Time" });
            QuickZones.Add(new QuickZoneItem { ZoneLabel = "EST / EDT", CityName = "New York", ZoneId = "Eastern Standard Time" });
            QuickZones.Add(new QuickZoneItem { ZoneLabel = "CST / CDT", CityName = "Chicago", ZoneId = "Central Standard Time" });
            QuickZones.Add(new QuickZoneItem { ZoneLabel = "MST / MDT", CityName = "Denver", ZoneId = "Mountain Standard Time" });
            QuickZones.Add(new QuickZoneItem { ZoneLabel = "PST / PDT", CityName = "Los Angeles", ZoneId = "Pacific Standard Time" });

            LstQuickSwitch.ItemsSource = QuickZones;
        }

        private void InitDropdowns()
        {
            var systemZones = TimeZoneInfo.GetSystemTimeZones().ToList();
            CmbConvertZone.ItemsSource = systemZones;
            CmbAllZones.ItemsSource = systemZones;

            var localMatch = systemZones.FirstOrDefault(z => z.Id == _initialSystemZoneId);
            if (localMatch != null)
            {
                CmbConvertZone.SelectedItem = localMatch;
            }
        }

        private void InitAnimations()
        {
            DoubleAnimation pulseAnim = new DoubleAnimation
            {
                From = 1.0,
                To = 1.8,
                Duration = new Duration(TimeSpan.FromSeconds(1.2)),
                AutoReverse = true,
                RepeatBehavior = RepeatBehavior.Forever
            };
            DoubleAnimation fadeAnim = new DoubleAnimation
            {
                From = 0.6,
                To = 0.0,
                Duration = new Duration(TimeSpan.FromSeconds(1.2)),
                AutoReverse = true,
                RepeatBehavior = RepeatBehavior.Forever
            };

            PulseScale.BeginAnimation(ScaleTransform.ScaleXProperty, pulseAnim);
            PulseScale.BeginAnimation(ScaleTransform.ScaleYProperty, pulseAnim);
            PulseRing.BeginAnimation(UIElement.OpacityProperty, fadeAnim);

            _particleTimer.Interval = TimeSpan.FromMilliseconds(33);
            _particleTimer.Tick += ParticleEngine_Tick;
        }

        private void OnThemeChanged(string themeName)
        {
            ApplyThemeVisuals(themeName);
        }

        private void ApplyThemeVisuals(string themeName)
        {
            AmbientMeshCanvas.Visibility = Visibility.Collapsed;
            ParticleCanvas.Visibility = Visibility.Collapsed;
            _particleTimer.Stop();

            if (themeName == "Cyberpunk" || themeName == "Nord")
            {
                ParticleCanvas.Visibility = Visibility.Visible;
                InitParticleSystem(themeName);
                _particleTimer.Start();
            }
            else if (themeName == "Dark" || themeName == "Light")
            {
                AmbientMeshCanvas.Visibility = Visibility.Visible;
                StartBreathingGlow();
            }
        }

        private void StartBreathingGlow()
        {
            DoubleAnimation orb1Opacity = new DoubleAnimation
            {
                From = 0.25, To = 0.65,
                Duration = new Duration(TimeSpan.FromSeconds(1.5)),
                AutoReverse = true, RepeatBehavior = RepeatBehavior.Forever
            };
            DoubleAnimation orb2Opacity = new DoubleAnimation
            {
                From = 0.15, To = 0.55,
                Duration = new Duration(TimeSpan.FromSeconds(1.8)),
                AutoReverse = true, RepeatBehavior = RepeatBehavior.Forever
            };

            DoubleAnimation orb1Scale = new DoubleAnimation
            {
                From = 0.8, To = 1.3,
                Duration = new Duration(TimeSpan.FromSeconds(2.0)),
                AutoReverse = true, RepeatBehavior = RepeatBehavior.Forever
            };
            DoubleAnimation orb2Scale = new DoubleAnimation
            {
                From = 0.9, To = 1.4,
                Duration = new Duration(TimeSpan.FromSeconds(2.2)),
                AutoReverse = true, RepeatBehavior = RepeatBehavior.Forever
            };

            DoubleAnimation orb1TranslateX = new DoubleAnimation
            {
                From = -30, To = 40,
                Duration = new Duration(TimeSpan.FromSeconds(2.5)),
                AutoReverse = true, RepeatBehavior = RepeatBehavior.Forever
            };
            DoubleAnimation orb2TranslateY = new DoubleAnimation
            {
                From = 20, To = -50,
                Duration = new Duration(TimeSpan.FromSeconds(2.8)),
                AutoReverse = true, RepeatBehavior = RepeatBehavior.Forever
            };

            GlowOrb1.BeginAnimation(UIElement.OpacityProperty, orb1Opacity);
            GlowOrb2.BeginAnimation(UIElement.OpacityProperty, orb2Opacity);

            Orb1Scale.BeginAnimation(ScaleTransform.ScaleXProperty, orb1Scale);
            Orb1Scale.BeginAnimation(ScaleTransform.ScaleYProperty, orb1Scale);
            Orb2Scale.BeginAnimation(ScaleTransform.ScaleXProperty, orb2Scale);
            Orb2Scale.BeginAnimation(ScaleTransform.ScaleYProperty, orb2Scale);

            Orb1Translate.BeginAnimation(TranslateTransform.XProperty, orb1TranslateX);
            Orb2Translate.BeginAnimation(TranslateTransform.YProperty, orb2TranslateY);
        }

        private void InitParticleSystem(string themeName)
        {
            ParticleCanvas.Children.Clear();
            _particles.Clear();
            _connectionLines.Clear();

            Brush particleBrush = themeName == "Cyberpunk" 
                ? new SolidColorBrush((Color)ColorConverter.ConvertFromString("#00F0FF"))
                : new SolidColorBrush((Color)ColorConverter.ConvertFromString("#88C0D0"));

            for (int i = 0; i < 28; i++)
            {
                var el = new Ellipse
                {
                    Width = _rand.Next(4, 7),
                    Height = _rand.Next(4, 7),
                    Fill = particleBrush,
                    Opacity = _rand.NextDouble() * 0.5 + 0.4
                };

                double pX = _rand.Next(0, 450);
                double pY = _rand.Next(0, 650);

                Canvas.SetLeft(el, pX);
                Canvas.SetTop(el, pY);
                ParticleCanvas.Children.Add(el);

                _particles.Add(new Particle
                {
                    X = pX,
                    Y = pY,
                    VX = (_rand.NextDouble() - 0.5) * 1.5,
                    VY = (_rand.NextDouble() - 0.5) * 1.5,
                    Element = el
                });
            }
        }

        private void ParticleEngine_Tick(object? sender, EventArgs e)
        {
            double width = this.ActualWidth > 0 ? this.ActualWidth : 480;
            double height = this.ActualHeight > 0 ? this.ActualHeight : 680;

            foreach (var p in _particles)
            {
                p.X += p.VX;
                p.Y += p.VY;

                if (p.X < 0 || p.X > width) p.VX *= -1;
                if (p.Y < 0 || p.Y > height) p.VY *= -1;

                Canvas.SetLeft(p.Element, p.X);
                Canvas.SetTop(p.Element, p.Y);
            }

            foreach (var line in _connectionLines)
            {
                ParticleCanvas.Children.Remove(line);
            }
            _connectionLines.Clear();

            Color strokeColor = App.CurrentTheme == "Cyberpunk" 
                ? (Color)ColorConverter.ConvertFromString("#FF007F")
                : (Color)ColorConverter.ConvertFromString("#88C0D0");

            double maxDistance = 85.0;
            for (int i = 0; i < _particles.Count; i++)
            {
                for (int j = i + 1; j < _particles.Count; j++)
                {
                    double dx = _particles[i].X - _particles[j].X;
                    double dy = _particles[i].Y - _particles[j].Y;
                    double dist = Math.Sqrt(dx * dx + dy * dy);

                    if (dist < maxDistance)
                    {
                        double alpha = (1.0 - (dist / maxDistance)) * 0.6;
                        Line line = new Line
                        {
                            X1 = _particles[i].X + 2,
                            Y1 = _particles[i].Y + 2,
                            X2 = _particles[j].X + 2,
                            Y2 = _particles[j].Y + 2,
                            Stroke = new SolidColorBrush(strokeColor),
                            StrokeThickness = 1.0,
                            Opacity = alpha
                        };

                        ParticleCanvas.Children.Add(line);
                        _connectionLines.Add(line);
                    }
                }
            }
        }

        private void Timer_Tick(object? sender, EventArgs e)
        {
            UpdateLiveTimes();
        }

        public void UpdateLiveTimes()
        {
            TxtCurrentZoneBanner.Text = TimeZoneInfo.Local.DisplayName;
            DateTime utcNow = DateTime.UtcNow;

            foreach (var item in QuickZones)
            {
                try
                {
                    TimeZoneInfo info = TimeZoneInfo.FindSystemTimeZoneById(item.ZoneId);
                    DateTime zoneTime = TimeZoneInfo.ConvertTimeFromUtc(utcNow, info);

                    string timeFormat = ShowSeconds ? "hh:mm:ss" : "hh:mm";
                    string formattedTime = zoneTime.ToString(timeFormat);
                    string amPm = zoneTime.ToString("tt").ToLower().Substring(0, 1);

                    string result = string.Empty;
                    if (ShowDayOfWeek)
                    {
                        result += $"{zoneTime.ToString("ddd")} ";
                    }
                    result += $"{formattedTime} {amPm}";

                    item.LiveTime = result;
                }
                catch (Exception ex)
                {
                    item.LiveTime = "--:--";
                    App.Log($"Error calculating time for {item.ZoneId}: {ex.Message}");
                }
            }
        }

        private void BtnSettings_Click(object sender, RoutedEventArgs e)
        {
            App.Log("Opening Settings window...");
            SettingsWindow settings = new SettingsWindow(this);
            settings.Owner = this;
            settings.ShowDialog();
        }

        private void BtnPin_Click(object sender, RoutedEventArgs e)
        {
            Topmost = !Topmost;
            BtnPin.Foreground = Topmost ? (Brush)FindResource("AccentBrush") : (Brush)FindResource("SecondaryTextBrush");
            App.Log($"Window pin state set to: {Topmost}");
        }

        private void BtnSwitchZone_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Button btn && btn.Tag is string zoneId)
            {
                ApplySystemTimezone(zoneId);
            }
        }

        private void BtnSwitchCustom_Click(object sender, RoutedEventArgs e)
        {
            if (CmbAllZones.SelectedValue is string zoneId)
            {
                ApplySystemTimezone(zoneId);
            }
        }

        private void ApplySystemTimezone(string zoneId)
        {
            App.Log($"Attempting to set system timezone to: '{zoneId}'");
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo("tzutil.exe", $"/s \"{zoneId}\"")
                {
                    CreateNoWindow = true,
                    UseShellExecute = false
                };
                Process? proc = Process.Start(psi);
                proc?.WaitForExit();

                App.Log($"tzutil.exe exited with code: {proc?.ExitCode}");
                UpdateLiveTimes();
            }
            catch (Exception ex)
            {
                App.Log($"FAILED to execute tzutil.exe: {ex}");
                MessageBox.Show($"Failed to set timezone: {ex.Message}", "Timezone Switcher", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnConvert_Click(object sender, RoutedEventArgs e)
        {
            if (!int.TryParse(TxtHour.Text, out int hour) || !int.TryParse(TxtMinute.Text, out int minute)) return;
            if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return;

            if (RbPM.IsChecked == true && hour < 12) hour += 12;
            if (RbAM.IsChecked == true && hour == 12) hour = 0;

            if (CmbConvertZone.SelectedItem is not TimeZoneInfo selectedSourceZone) return;

            DateTime today = DateTime.Today;
            DateTime sourceDateTime = new DateTime(today.Year, today.Month, today.Day, hour, minute, 0);

            foreach (var item in QuickZones)
            {
                try
                {
                    TimeZoneInfo targetZone = TimeZoneInfo.FindSystemTimeZoneById(item.ZoneId);
                    DateTime converted = TimeZoneInfo.ConvertTime(sourceDateTime, selectedSourceZone, targetZone);
                    string amPm = converted.ToString("tt").ToLower().Substring(0, 1);
                    item.ConvertedTime = $"{converted:hh:mm} {amPm}";
                }
                catch
                {
                    item.ConvertedTime = "--:--";
                }
            }
        }

        private void BtnNow_Click(object sender, RoutedEventArgs e)
        {
            DateTime now = DateTime.Now;
            int h = now.Hour;
            TxtMinute.Text = now.Minute.ToString("D2");

            if (h >= 12)
            {
                RbPM.IsChecked = true;
                TxtHour.Text = (h > 12 ? h - 12 : 12).ToString();
            }
            else
            {
                RbAM.IsChecked = true;
                TxtHour.Text = (h == 0 ? 12 : h).ToString();
            }

            BtnConvert_Click(sender, e);
        }

        private void Window_Closing(object sender, CancelEventArgs e)
        {
            App.ThemeChanged -= OnThemeChanged;
            _particleTimer.Stop();

            App.Log($"Window closing. Reverting system timezone to original: '{_initialSystemZoneId}'");
            ApplySystemTimezone(_initialSystemZoneId);
            App.Log("================ Application Exited ================");
        }
    }
}
"@

$SettingsWindowXamlContent = @"
<Window x:Class="$ProjectName.SettingsWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Settings" Height="620" Width="400"
        WindowStartupLocation="CenterOwner"
        AllowsTransparency="True"
        WindowStyle="None"
        Background="Transparent"
        Foreground="{DynamicResource PrimaryTextBrush}"
        ResizeMode="NoResize">

    <Border CornerRadius="12" Background="{DynamicResource WindowBackgroundBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" ClipToBounds="True">
        <Grid Margin="12">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <TextBlock Grid.Row="0" Text="Settings" FontSize="18" FontWeight="Bold" Foreground="{DynamicResource PrimaryTextBrush}" HorizontalAlignment="Center" Margin="0,0,0,12"/>

            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                <StackPanel>
                    <!-- Theme Section -->
                    <GroupBox Header="Theme" Foreground="{DynamicResource SecondaryTextBrush}" BorderBrush="{DynamicResource BorderBrush}" Padding="10" Margin="0,0,0,10">
                        <StackPanel x:Name="ThemeRadioPanel">
                            <RadioButton x:Name="RbThemeDark" Content="Dark (Fast Ambient Glow)" Tag="Dark" IsChecked="True" Foreground="{DynamicResource PrimaryTextBrush}" Margin="0,3" Checked="Theme_Checked"/>
                            <RadioButton x:Name="RbThemeLight" Content="Light (Fast Ambient Glow)" Tag="Light" Foreground="{DynamicResource PrimaryTextBrush}" Margin="0,3" Checked="Theme_Checked"/>
                            <RadioButton x:Name="RbThemeCyberpunk" Content="Cyberpunk (Connected Network)" Tag="Cyberpunk" Foreground="{DynamicResource PrimaryTextBrush}" Margin="0,3" Checked="Theme_Checked"/>
                            <RadioButton x:Name="RbThemeNord" Content="Nord (Connected Network)" Tag="Nord" Foreground="{DynamicResource PrimaryTextBrush}" Margin="0,3" Checked="Theme_Checked"/>
                            <RadioButton x:Name="RbThemeWin95" Content="Win95 (Classic)" Tag="Win95" Foreground="{DynamicResource PrimaryTextBrush}" Margin="0,3" Checked="Theme_Checked"/>
                        </StackPanel>
                    </GroupBox>

                    <!-- Transparency Section -->
                    <GroupBox Header="Transparency Level" Foreground="{DynamicResource SecondaryTextBrush}" BorderBrush="{DynamicResource BorderBrush}" Padding="10" Margin="0,0,0,10">
                        <StackPanel>
                            <Grid Margin="0,0,0,6">
                                <TextBlock Text="Window Opacity" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="12" VerticalAlignment="Center"/>
                                <TextBlock x:Name="TxtOpacityValue" Text="80%" Foreground="{DynamicResource AccentBrush}" FontWeight="Bold" FontSize="12" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                            </Grid>
                            <Slider x:Name="SldOpacity" Minimum="0.10" Maximum="1.0" Value="0.80" SmallChange="0.05" LargeChange="0.1" TickFrequency="0.05" IsSnapToTickEnabled="True" ValueChanged="SldOpacity_ValueChanged" Cursor="Hand"/>
                        </StackPanel>
                    </GroupBox>

                    <!-- Font Section -->
                    <GroupBox Header="Font" Foreground="{DynamicResource SecondaryTextBrush}" BorderBrush="{DynamicResource BorderBrush}" Padding="10" Margin="0,0,0,10">
                        <ComboBox x:Name="CmbFontFamily" Background="{DynamicResource InputBackgroundBrush}" Foreground="#000000" BorderBrush="{DynamicResource BorderBrush}" Padding="4" SelectionChanged="CmbFontFamily_SelectionChanged"/>
                    </GroupBox>

                    <!-- Display Options -->
                    <GroupBox Header="Display Options" Foreground="{DynamicResource SecondaryTextBrush}" BorderBrush="{DynamicResource BorderBrush}" Padding="10" Margin="0,0,0,10">
                        <StackPanel>
                            <CheckBox x:Name="ChkShowSeconds" Content="Show seconds" Foreground="{DynamicResource PrimaryTextBrush}" Margin="0,3" Checked="DisplayOption_Changed" Unchecked="DisplayOption_Changed"/>
                            <CheckBox x:Name="ChkShowDayOfWeek" Content="Show day of week" Foreground="{DynamicResource PrimaryTextBrush}" Margin="0,3" Checked="DisplayOption_Changed" Unchecked="DisplayOption_Changed"/>
                            <Separator Background="{DynamicResource BorderBrush}" Margin="0,6"/>
                            <CheckBox x:Name="ChkEnableLogging" Content="Enable Debug Logging (./log/app.log)" Foreground="{DynamicResource AccentBrush}" FontWeight="SemiBold" Margin="0,3" Checked="ChkEnableLogging_Changed" Unchecked="ChkEnableLogging_Changed"/>
                        </StackPanel>
                    </GroupBox>
                </StackPanel>
            </ScrollViewer>

            <!-- Close Button -->
            <Button Grid.Row="2" Content="Close" Click="BtnClose_Click" Width="90" Padding="6" Background="{DynamicResource AccentBrush}" Foreground="#FFFFFF" FontWeight="Bold" BorderThickness="0" Cursor="Hand" HorizontalAlignment="Center" Margin="0,8,0,0"/>
        </Grid>
    </Border>
</Window>
"@

$SettingsWindowCsContent = @"
using System;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace $ProjectName
{
    public partial class SettingsWindow : Window
    {
        private readonly MainWindow _main;
        private bool _isInitializing = true;

        public SettingsWindow(MainWindow main)
        {
            InitializeComponent();
            _main = main;

            CmbFontFamily.ItemsSource = Fonts.SystemFontFamilies.OrderBy(f => f.Source);
            CmbFontFamily.SelectedItem = _main.FontFamily;

            ChkShowSeconds.IsChecked = _main.ShowSeconds;
            ChkShowDayOfWeek.IsChecked = _main.ShowDayOfWeek;
            ChkEnableLogging.IsChecked = App.IsLoggingEnabled;

            SldOpacity.Value = App.WindowOpacityLevel;
            TxtOpacityValue.Text = $"{(int)(App.WindowOpacityLevel * 100)}%";

            SelectActiveThemeRadio(App.CurrentTheme);

            _isInitializing = false;
        }

        private void SelectActiveThemeRadio(string theme)
        {
            switch (theme)
            {
                case "Light": RbThemeLight.IsChecked = true; break;
                case "Cyberpunk": RbThemeCyberpunk.IsChecked = true; break;
                case "Nord": RbThemeNord.IsChecked = true; break;
                case "Win95": RbThemeWin95.IsChecked = true; break;
                default: RbThemeDark.IsChecked = true; break;
            }
        }

        private void SldOpacity_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
        {
            if (_isInitializing || TxtOpacityValue == null) return;

            double opacityVal = Math.Round(e.NewValue, 2);
            TxtOpacityValue.Text = $"{(int)(opacityVal * 100)}%";
            App.SetWindowOpacity(opacityVal);
        }

        private void Theme_Checked(object sender, RoutedEventArgs e)
        {
            if (_isInitializing || _main == null) return;
            if (sender is RadioButton rb && rb.Tag is string themeName)
            {
                App.SetTheme(themeName);
            }
        }

        private void CmbFontFamily_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_isInitializing) return;
            if (_main != null && CmbFontFamily.SelectedItem is FontFamily fontFamily)
            {
                _main.FontFamily = fontFamily;
                this.FontFamily = fontFamily;
            }
        }

        private void DisplayOption_Changed(object sender, RoutedEventArgs e)
        {
            if (_isInitializing || _main == null) return;
            _main.ShowSeconds = ChkShowSeconds.IsChecked ?? false;
            _main.ShowDayOfWeek = ChkShowDayOfWeek.IsChecked ?? false;
            _main.UpdateLiveTimes();
        }

        private void ChkEnableLogging_Changed(object sender, RoutedEventArgs e)
        {
            if (_isInitializing) return;
            App.IsLoggingEnabled = ChkEnableLogging.IsChecked ?? false;
            App.Log($"Logging state changed to: {App.IsLoggingEnabled}");
        }

        private void BtnClose_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }
    }
}
"@

$AppManifestContent = @"
<?xml version="1.0" encoding="utf-8"?>
<assembly manifestVersion="1.0" xmlns="urn:schemas-microsoft-com:asm.v1">
  <assemblyIdentity version="1.0.0.0" name="$ProjectName.app"/>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}" />
    </application>
  </compatibility>
  <application xmlns="urn:schemas-microsoft-com:asm.v3">
    <windowsSettings>
      <dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">PerMonitorV2</dpiAwareness>
    </windowsSettings>
  </application>
</assembly>
"@

Write-Host "[2/5] Creating project source files..." -ForegroundColor Cyan
Set-Content -Path (Join-Path $TargetDir "$ProjectName.csproj") -Value $CsprojContent
Set-Content -Path (Join-Path $TargetDir "App.xaml") -Value $AppXamlContent
Set-Content -Path (Join-Path $TargetDir "App.xaml.cs") -Value $AppCsContent
Set-Content -Path (Join-Path $TargetDir "MainWindow.xaml") -Value $MainWindowXamlContent
Set-Content -Path (Join-Path $TargetDir "MainWindow.xaml.cs") -Value $MainWindowCsContent
Set-Content -Path (Join-Path $TargetDir "SettingsWindow.xaml") -Value $SettingsWindowXamlContent
Set-Content -Path (Join-Path $TargetDir "SettingsWindow.xaml.cs") -Value $SettingsWindowCsContent
Set-Content -Path (Join-Path $TargetDir "app.manifest") -Value $AppManifestContent

Write-Host "[3/5] Verifying .NET SDK..." -ForegroundColor Cyan
if (-not (Get-Command "dotnet" -ErrorAction SilentlyContinue)) {
    Write-Error ".NET SDK is not installed or not added to PATH. Please install .NET SDK to proceed."
    exit
}

Write-Host "[4/5] Restoring packages and building standalone single-file binary..." -ForegroundColor Cyan
Set-Location $TargetDir
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true

$OutputPath = Join-Path $TargetDir "bin\Release\net10.0-windows\win-x64\publish"
Write-Host "`n[5/5] Build Complete!" -ForegroundColor Green
Write-Host "Your single standalone executable is located at:" -ForegroundColor Yellow
Write-Host "$OutputPath\TimezoneSwitcher.exe"
