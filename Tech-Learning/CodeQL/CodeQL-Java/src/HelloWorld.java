package src;
import java.util.*;

class Solution {
    public List<List<String>> groupAnagrams(String[] strs) {
        int j = 1;
        int i = 1 + j;
        List<List<String>> result_list = new ArrayList<>();
        Map<String, List<String>> m = new HashMap<>();
        for (String str:strs){
            char[] char_array = str.toCharArray();
            Arrays.sort(char_array);
            String sorted_str = new String(char_array);
            if (m.containsKey(sorted_str)){
                m.get(sorted_str).add(str);
            }
            else{
                List<String> list = new ArrayList<>();
                list.add(str);
                m.put(sorted_str, list);
            }
        }
        result_list.addAll(m.values());
        return result_list;
    }
}