/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 * @flow
 */

import React from 'react';
import {
  SafeAreaView,
  StyleSheet,
  ScrollView,
  View,
  Text,
  StatusBar,
  Button
} from 'react-native';

import {
  Header,
  LearnMoreLinks,
  Colors,
  DebugInstructions,
  ReloadInstructions,
} from 'react-native/Libraries/NewAppScreen';
import RNBambuserBroadcaster from 'react-native-bambuser-broadcaster';
import RNBambuserPlayer from 'react-native-bambuser-player';
console.log("RNBambuserPlayerRNBambuserPlayer",RNBambuserPlayer)


// console.log("RNBambuserBroadcasterRNBambuserBroadcaster",RNBambuserBroadcaster)


class App extends React.Component {
  componentDidMount(){
   
  }
  render(){
    return (
      <View style={{height: 1000,backgroundColor : "red"}}>
     
      <RNBambuserBroadcaster ref={ref => {this.myBroadcasterRef = ref; }} style={{height: 600,backgroundColor : "red"}} applicationId={"L5OLXCmxu3FrNOzLGpyb7w"} />
      <Button onPress={()=>{ this.myBroadcasterRef.startBroadcast();} } title={"Start"}/>
      <Button onPress={()=>{ this.myBroadcasterRef.stopBroadcast();
      this.myBroadcasterRef.endTalkback();
      } } title={"Stop"}/>
      {/* <RNBambuserPlayer  
     resourceUri={"https://cdn.bambuser.net/groups/87246/broadcasts?by_authors=&title_contains=&has_any_tags=&has_all_tags=&da_id=15c7b7ad-bc4f-87d4-cea1-f2a7d4f3fd76&da_timestamp=1580368786&da_signature_method=HMAC-SHA256&da_ttl=0&da_static=1&da_signature=a9b48255e467a556e3fefbd81515f0dbd04504bccde6e38c8f16d82deee82663"} 
      style={{height: 200,backgroundColor : "red"}} applicationId={"L5OLXCmxu3FrNOzLGpyb7w"} /> */}
        {/* <StatusBar barStyle="dark-content" />
        <SafeAreaView>
        <View style={{height : 100, backgroundColor : "red"}}>
  <RNBambuserBroadcaster applicationId={"L5OLXCmxu3FrNOzLGpyb7w"} />
  </View> */}
          {/* <ScrollView
            contentInsetAdjustmentBehavior="automatic"
            style={styles.scrollView}>
  
            {global.HermesInternal == null ? null : (
              <View style={styles.engine}>
                <Text style={styles.footer}>Engine: Hermes</Text>
              </View>
            )}
            <View style={styles.body}>
              <View style={styles.sectionContainer}>
                <Text style={styles.sectionTitle}>Step One</Text>
                <Text style={styles.sectionDescription}>
                  Edit <Text style={styles.highlight}>App.js</Text> to change this
                  screen and then come back to see your edits.
                </Text>
              </View>
              <View style={styles.sectionContainer}>
                <Text style={styles.sectionTitle}>See Your Changes</Text>
                <Text style={styles.sectionDescription}>
                  <ReloadInstructions />
                </Text>
              </View>
              <View style={styles.sectionContainer}>
                <Text style={styles.sectionTitle}>Debug</Text>
                <Text style={styles.sectionDescription}>
                  <DebugInstructions />
                </Text>
              </View>
              <View style={styles.sectionContainer}>
                <Text style={styles.sectionTitle}>Learn More</Text>
                <Text style={styles.sectionDescription}>
                  Read the docs to discover what to do next:
                </Text>
              </View>
              <LearnMoreLinks />
            </View>
          </ScrollView> */}
        {/* </SafeAreaView> */}
        </View>
    );
  }
 
};

const styles = StyleSheet.create({
  scrollView: {
    backgroundColor: Colors.lighter,
  },
  engine: {
    position: 'absolute',
    right: 0,
  },
  body: {
    backgroundColor: Colors.white,
  },
  sectionContainer: {
    marginTop: 32,
    paddingHorizontal: 24,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '600',
    color: Colors.black,
  },
  sectionDescription: {
    marginTop: 8,
    fontSize: 18,
    fontWeight: '400',
    color: Colors.dark,
  },
  highlight: {
    fontWeight: '700',
  },
  footer: {
    color: Colors.dark,
    fontSize: 12,
    fontWeight: '600',
    padding: 4,
    paddingRight: 12,
    textAlign: 'right',
  },
});

export default App;
