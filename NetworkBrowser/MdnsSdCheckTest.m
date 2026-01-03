/*
 * MdnsSdCheckTest.m - Test mDNS-SD availability check
 *
 * This tool demonstrates how the NetworkBrowser checks for mDNS-SD support
 * and verifies that NSNetServiceBrowser is available in the GNUstep installation.
 */

#import <Foundation/Foundation.h>

int main(int argc, char *argv[])
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSLog(@"================================================");
  NSLog(@"mDNS-SD Support Check");
  NSLog(@"================================================");
  NSLog(@"");
  
  /* Check if NSNetServiceBrowser is available */
  Class netServiceBrowserClass = NSClassFromString(@"NSNetServiceBrowser");
  
  if (netServiceBrowserClass)
    {
      NSLog(@"✓ SUCCESS: NSNetServiceBrowser class is available");
      NSLog(@"  This GNUstep installation HAS mDNS-SD support");
      NSLog(@"");
      NSLog(@"  - NSNetServiceBrowser: %@", netServiceBrowserClass);
      
      /* Check for related classes */
      Class netServiceClass = NSClassFromString(@"NSNetService");
      if (netServiceClass)
        NSLog(@"  - NSNetService: %@", netServiceClass);
      
      Class netServiceDelegateClass = NSClassFromString(@"NSNetServiceDelegate");
      if (netServiceDelegateClass)
        NSLog(@"  - NSNetServiceDelegate: %@", netServiceDelegateClass);
      
      NSLog(@"");
      NSLog(@"Action: NetworkBrowser will proceed with service discovery");
    }
  else
    {
      NSLog(@"✗ WARNING: NSNetServiceBrowser class NOT available");
      NSLog(@"  This GNUstep installation does NOT have mDNS-SD support");
      NSLog(@"");
      NSLog(@"To fix this issue:");
      NSLog(@"  1. Install libdns_sd development files");
      NSLog(@"     - Debian/Ubuntu: sudo apt-get install libavahi-compat-libdnssd-dev");
      NSLog(@"     - Fedora/RHEL: sudo dnf install avahi-compat-libdns_sd-devel");
      NSLog(@"     - FreeBSD/OpenBSD: sudo pkg install mDNSResponder");
      NSLog(@"     - macOS: Xcode Command Line Tools (xcode-select --install)");
      NSLog(@"");
      NSLog(@"  2. Rebuild GNUstep with DNS-SD support");
      NSLog(@"");
      NSLog(@"Action: NetworkBrowser will show warning and ask user to continue or quit");
    }
  
  NSLog(@"");
  NSLog(@"================================================");
  
  [pool drain];
  return netServiceBrowserClass ? 0 : 1;
}
