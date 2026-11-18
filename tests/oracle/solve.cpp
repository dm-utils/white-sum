// independent exact solver: iterative deepening with transposition table; rules from design.md 2
#include <bits/stdc++.h>
using namespace std;
int W,H;
typedef string S; // W*H chars, idx y*W+x, y up, '\0' empty, 1..5
static void settle(S&s){for(int x=0;x<W;x++){int wr=0;for(int y=0;y<H;y++){char v=s[y*W+x];if(v){s[y*W+x]=0;s[wr*W+x]=v;wr++;}}}}
static void resolve(S&s){
  settle(s);
  while(true){
    vector<char> gone(W*H,0);bool any=false;
    for(int y=0;y<H;y++){int x=0;while(x<W){if(!s[y*W+x]){x++;continue;}int x1=x,sum=0;while(x1<W&&s[y*W+x1]){sum+=s[y*W+x1];x1++;}if(sum==10){for(int k=x;k<x1;k++)gone[y*W+k]=1;any=true;}x=x1;}}
    for(int x=0;x<W;x++){int y=0;while(y<H){if(!s[y*W+x]){y++;continue;}int y1=y,sum=0;while(y1<H&&s[y1*W+x]){sum+=s[y1*W+x];y1++;}if(sum==10){for(int k=y;k<y1;k++)gone[k*W+x]=1;any=true;}y=y1;}}
    if(!any)return;
    for(int i=0;i<W*H;i++)if(gone[i])s[i]=0;
    settle(s);
  }
}
static bool apply(const S&s,int x,int y,int d,S&out){ // d 0 R 1 L 2 U(swap up)
  int dx=d==0?1:d==1?-1:0,dy=d==2?1:0;int nx=x+dx,ny=y+dy;
  if(nx<0||nx>=W||ny<0||ny>=H)return false;char a=s[y*W+x],b=s[ny*W+nx];
  if(!a||a==b)return false;if(!b&&dy)return false;
  out=s;out[y*W+x]=b;out[ny*W+nx]=a;resolve(out);return true;}
static int tiles(const S&s){int n=0;for(char c:s)n+=c!=0;return n;}
unordered_map<S,int> tt; // tt[s]=r: not clearable within r moves
long long exps;
static void moves(const S&s,vector<S>&ch){ // all distinct canonical results
  S o;set<S> dedup;
  for(int y=0;y<H;y++)for(int x=0;x<W;x++){if(!s[y*W+x])continue;
    for(int d=0;d<3;d++){ if(d==1){ // slide left only if empty target; swap left dup of right
        if(x==0||s[y*W+x-1])continue;}
      if(apply(s,x,y,d,o))dedup.insert(o);}}
  ch.assign(dedup.begin(),dedup.end());}
static bool dfs(const S&s,int r){
  if(tiles(s)==0)return true;
  if(r==0)return false;
  auto it=tt.find(s);if(it!=tt.end()&&it->second>=r)return false;
  exps++;
  vector<S> ch;moves(s,ch);
  if(r==1){for(auto&c:ch)if(tiles(c)==0)return true;}
  else{
    stable_sort(ch.begin(),ch.end(),[](const S&a,const S&b){return tiles(a)<tiles(b);});
    for(auto&c:ch)if(dfs(c,r-1))return true;}
  tt[s]=r;return false;}
int main(int argc,char**argv){
  // input lines: w h rows(top first, '.'=empty) maxdepth ; output minimal moves
  string line;
  while(getline(cin,line)){
    stringstream ss(line);int maxd;string rows;ss>>W>>H>>rows>>maxd;
    S s(W*H,0);
    for(int ry=0;ry<H;ry++)for(int x=0;x<W;x++){char c=rows[ry*W+x];s[(H-1-ry)*W+x]=c=='.'?0:c-'0';}
    tt.clear();exps=0;int ans=-1;
    for(int r=1;r<=maxd;r++){if(dfs(s,r)){ans=r;break;}}
    printf("%d %lld\n",ans,exps);fflush(stdout);
  }
}
